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
`codesign --verify` for device builds). It also verifies the engine commit
embedded in the shipped binary, because a template hash only proves which file
was available, not which one the exporter linked.

Device and simulator outputs go to separate directories (`build/visionos` and
`build/visionos-simulator`) so a simulator build can never be mistaken for
something that ran on hardware.

### Simulator builds need a patched engine

The pinned template only supports the `.layered` compositor layout, which the
simulator cannot provide, so a simulator build against it exits at startup with
a `fatalError`. Simulator support lives on the engine branch
`clancey-visionos-dedicated-layout`; build its simulator slice, inject it into a
copy of the template, and point the build at that copy:

```bash
GODOT_VISIONOS_TEMPLATE=/path/to/patched.zip \
GODOT_VISIONOS_TEMPLATE_SHA256=<sha256 of that zip> \
GODOT_VISIONOS_ENGINE_COMMIT=<engine commit it was built from> \
  build-tools/visionos/build.sh simulator debug
```

The override is staged into the path `export_presets.cfg` hardcodes and the
pinned template is restored afterwards, including on failure. Set
`GODOT_VISIONOS_ENGINE_COMMIT` as well: without it the build asserts the pinned
identity against a deliberately different engine and fails.

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

### Scene manifest

The exporter writes two halves of the scene manifest that do not agree. It names
`CPSceneSessionRoleImmersiveSpaceApplication` (CompositorServices) as
`UIApplicationPreferredDefaultSceneSessionRole`, but files the immersion style
under `UISceneSessionRoleImmersiveSpaceApplication` (UIKit) — the same name one
prefix apart. The runtime creates a `CPImmersiveScene`, finds no configuration
for that role, falls back to the mixed style, and SwiftUI reports it as a Fault
that the headset surfaces as an immersion prompt.

`build.sh` adds the missing configuration to the exported project between export
and `xcodebuild`. The configuration carries `UISceneConfigurationName` as well as
`UISceneInitialImmersionStyle`: without the name UIKit logs `Info.plist contained
no configuration named "Default Configuration"` and falls back to the first entry
defined, which is right by accident rather than by lookup.

Both values are read back out of the exported plist *and* asserted again on the
shipped bundle, because the patch edits the build's input and the bundle is what
ships. An unexpected preferred role fails the build rather than skipping, so a
future template that changes the role cannot leave a green log beside an
unpatched plist.

The fix is confirmed by behaviour, not by the plist: the compositor logs
`initialImmersionStyle: FullImmersionStyle()`, which is the style it applied
rather than the style that was requested.

## What the port does

**Bootstrap** (`OQ_Toolkit/vr_autoload.gd`). `initialize()` branches to
`_initialize_native_visionos()` before the OpenXR path. It initialises the
`visionOS` interface once, then sets `use_xr`, `vrs_mode = VRS_XR` and `use_hdr_2d`
on the root viewport. If the interface is missing or fails to initialise it logs a
visible error and leaves `inVR` false rather than rendering to no presenter.

**Camera.** `apply_camera_near_plane()` raises the tracked camera's near plane to
the platform minimum (0.11 m of physical distance), scaled by `XRServer.world_scale`
and never pulled closer than the project already had it.

**Immersion.** Fully immersive only, and never switched at runtime. The export
preset requests `application/immersion_style=0` (Full), and the build files that
style under `CPSceneSessionRoleImmersiveSpaceApplication` — the role the app
actually requests — because the exporter files it under the UIKit role instead,
one prefix apart, which makes the runtime fall back to the mixed style and raise
a SwiftUI Fault. See "Scene manifest" below.

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

* Headless test suite: 65 passed, 1 failed. The failure is
  `test_level_hash.test_v4_level_hash_uses_beatmap_and_lightshow_files`, which
  needs the copyrighted shipped maps — gitignored and absent from any clean
  clone — and fails identically on the unmodified base commit. `build.sh`
  allowlists exactly that test by name, so any other failure stops the build.
* `--import` completes with no script, parse or compile errors.
* Export and `xcodebuild -sdk xros -destination 'generic/platform=visionOS'`
  succeed; the result is an arm64 device slice.
* `codesign --verify --deep --strict` passes and the bundle satisfies its
  designated requirement, `TeamIdentifier=6TMAULLKT8`.
* `Info.plist` contains `CPSceneSessionRoleImmersiveSpaceApplication`,
  `UISceneInitialImmersionStyle = UIImmersionStyleFull`,
  `NSHandsTrackingUsageDescription` and `NSAccessoryTrackingUsageDescription`.
* The WebRTC GDExtension's visionOS slices are embedded and signed in the bundle.
* `build.sh` verifies the engine commit embedded in the **shipped binary**, not
  just the template hash, and asserts the pinned commit is absent whenever an
  override is in play. The check has been exercised against known-bad inputs and
  confirmed to reject them.

### Ran on Vision Pro hardware

The app installs, launches and renders on a real headset. Open defects observed
there: saber blade orientation, a horizontally cropped menu panel, and ~29
pipeline errors at startup.

**This was an engine without the compositor-layout and view-count changes below.**
Those changes have not been re-verified on hardware.

### Ran on the visionOS simulator

The app boots, stays alive, and transfers rendered scene frames
(`scene≈2800` per 3000 encoded). This required engine work, because the
simulator drawable is **monoscopic** (one view, one non-array texture) and Godot
assumed stereo:

* Accept the `.dedicated` compositor layout, with foveation disabled.
* Report the real view count instead of a hardcoded `2`; claiming stereo on a
  one-view layer drives the renderer into multiview render passes that the
  simulator GPU (Apple2) cannot create at all.
* Allocate scene targets with a matching layer count.
* Disable MSAA on the simulator GPU, applied before `use_xr` is enabled.

Together these took the error flood from 1,250,912 errors and a 160 MB log to
124 errors and 24 KB.

`simctl io screenshot` returns a blank frame for immersive content, so it cannot
visually confirm rendering. The scene-transfer counter is the evidence.

## Not verified

* **The `.layered` hardware path after the engine changes.** Under `.layered`
  the view count is 2, so every changed expression evaluates to the constant it
  replaced — but that is an argument from construction and code review, not a
  hardware run. It has not been tested on a headset.
* Whether the ~29 startup pipeline errors are a real defect. They are a bounded
  startup burst, not per-frame, and the same count appears on both device and
  simulator, which suggests a pre-existing engine issue rather than one
  introduced by this port. Not proven either way.
* Saber blade orientation and the cropped menu panel. Both need a headset to
  diagnose; the geometry diagnostic that would resolve them has not been run on
  hardware.
* Optical-hand saber play, the grasp-to-pause mapping, and accessory/optical
  handover have not been exercised against a real runtime.
* Whether glow composites acceptably against passthrough in Mixed immersion.
* Comfort. No one has played this.
* No release build has been produced; only signed debug builds. The release
  slices of the patched templates embed neither engine commit and are
  uncharacterised — do not use them for a release build.

Spatial anchors, world anchors and room persistence are not used by this game, so
none of that surface is exercised by the port.
