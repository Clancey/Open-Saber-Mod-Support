# visionOS port

Open Saber runs natively on Apple Vision Pro through the CompositorServices/Metal/ARKit
XR backend, alongside the existing OpenXR (Quest, SteamVR) and WebXR builds. The Quest,
desktop and Web paths are untouched: every visionOS behaviour is either behind a
`.visionos` project-setting feature tag or behind a `VisionOSPlatform.is_native_platform()`
runtime check.

## Engine

visionOS is not supported by upstream Godot. This port builds against a pinned fork:

| | |
|---|---|
| Repository | `Clancey/godot`, branch `clancey-visionos` |
| Commit | `643c5348568a4a227bdc5119d6c8a0074fc3c9be` |
| Editor version string | `4.8.dev.custom_build.643c53485` |
| Editor SHA-256 | `60e435163f95a3dfed5af0a2a022f16b8f058e4aa2f7e99ee985ed13ad0f8fd0` |
| `visionos.zip` SHA-256 | `7a0d722034aec6d1b3927b6713f74011e00215a270d1800b37785106fa4c01a4` |

The 190 MB export template is not committed. Copy it to
`build-tools/visionos/visionos.zip`; `build.sh` refuses to run if either hash does
not match, because an artifact you cannot trace back to an engine commit is not
evidence of anything.

The rest of the project still targets Godot 4.7 (`config/features` is unchanged). The
4.8 editor rewrites `*.import` files with new importer defaults — those rewrites are
local churn and should not be committed.

## Building

```bash
build-tools/visionos/build.sh device debug        # or: simulator, release
```

The script verifies the engine hashes, imports, runs the test suite, exports the
Xcode project, builds with `xcodebuild`, and prints the artifact's identity
(bundle id, immersion style, executable/PCK/Info.plist hashes, dSYM UUID, and
`codesign --verify` for device builds).

Device and simulator outputs go to separate directories (`build/visionos` and
`build/visionos-simulator`) so a simulator build can never be mistaken for
something that ran on hardware.

### Signing

Export presets 5 (`visionOS`) and 6 (`visionOS Simulator`) use bundle ids
`com.clancey.opensaber` / `com.clancey.opensaber.simulator` and team `6TMAULLKT8`.

Signing is split in two, deliberately:

* **GDExtension dylibs** are signed by Godot at export time with an exact
  certificate SHA-1, because `Apple Development` is ambiguous when a machine holds
  more than one development certificate and the export aborts on ambiguity.
* **The app bundle** is signed by `xcodebuild` with automatic signing, because the
  only profile covering this bundle id is Xcode-managed and manual signing rejects
  a managed profile.

## What the port does

**Bootstrap** (`OQ_Toolkit/vr_autoload.gd`). `initialize()` branches to
`_initialize_native_visionos()` before the OpenXR path. It initialises the
`visionOS` interface once, then sets `use_xr`, `vrs_mode = VRS_XR` and `use_hdr_2d`
on the root viewport. If the interface is missing or fails to initialise it logs a
visible error and leaves `inVR` false rather than rendering to no presenter.

**Camera.** `apply_camera_near_plane()` raises the tracked camera's near plane to
the platform minimum (0.11 m of physical distance), scaled by `XRServer.world_scale`
and never pulled closer than the project already had it.

**Immersion.** Full immersive by default. `Settings.visionos_passthrough` (a toggle
in the settings panel, hidden on other platforms) switches the native immersion
style to Mixed. The transparent background and hidden virtual floor are only
applied once the interface *confirms* the style change, so a refused switch leaves
a normal immersive scene instead of an empty one.

**Input.** Optical hands and real spatial controllers both publish onto the
reserved `left_hand` / `right_hand` trackers, and the engine already gives a
physical accessory precedence over optical tracking on the same hand, so the
existing `XRController3D` rig drives the sabers either way.
`BeepSaberController` resolves which source is live each frame and:

* maps grasp (`grip_click`) to the menu action on optical hands, since they publish
  no face buttons and `grip` is otherwise unused by the game — this keeps pause
  reachable without an accessory;
* suppresses `trigger_haptic_pulse` on optical hands, which have no haptics and
  would otherwise produce an engine error every rumble;
* treats a source change as an input transition: held state is dropped and neutral
  input is required before the new source can fire an action.

**Saber calibration.** The four `*_saber_offset_*` settings are persisted under a
`visionos_` prefix. They calibrate the held saber model against the platform's aim
pose, so a value tuned against a Touch controller is meaningless against a visionOS
aim pose; visionOS starts at zero and the Quest value stays saved under its
original key.

## Verified

* Headless test suite: 53 passed, 4 failed. The 4 failures are `test_level_hash`
  tests that need the copyrighted shipped maps, which are gitignored and absent
  from any clean clone; they fail identically on the unmodified base commit.
  `build.sh` allowlists exactly those four by name, so any other failure stops
  the build.
* `--import` completes with no script, parse or compile errors.
* Export and `xcodebuild -sdk xros -destination 'generic/platform=visionOS'`
  succeed; the result is an arm64 device slice.
* `codesign --verify --deep --strict` passes and the bundle satisfies its
  designated requirement, `TeamIdentifier=6TMAULLKT8`.
* `Info.plist` contains `CPSceneSessionRoleImmersiveSpaceApplication`,
  `UISceneInitialImmersionStyle = UIImmersionStyleFull`,
  `NSHandsTrackingUsageDescription` and `NSAccessoryTrackingUsageDescription`.
* The WebRTC GDExtension's visionOS slices are embedded and signed in the bundle.

## Not verified

Everything below needs a headset and a wearer; none of it has been done.

* The app has never been installed or launched on Vision Pro hardware or the
  simulator. Nothing here is evidence that the game renders, tracks or plays.
* Optical-hand saber play, the grasp-to-pause mapping, and accessory/optical
  handover have not been exercised against a real runtime.
* Whether glow composites acceptably against passthrough in Mixed immersion.
* Comfort. No one has worn this.
* No release build has been produced; only a signed debug device build.

Spatial anchors, world anchors and room persistence are not used by this game, so
none of that surface is exercised by the port.
