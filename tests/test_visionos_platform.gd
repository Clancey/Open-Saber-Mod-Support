extends "res://tests/test_case.gd"

## Covers the pure decision helpers used by the native visionOS port. These run
## headless on any host, so they also guard the non-visionOS platforms against
## regressions in the shared code paths.


func test_classify_accessory_requires_both_poses() -> void:
	assert_eq(
		VisionOSPlatform.classify_input_source(VisionOSPlatform.ACCESSORY_PROFILE, true, true),
		VisionOSPlatform.InputSource.SPATIAL_CONTROLLER,
		"A fully tracked accessory drives the saber"
	)
	assert_eq(
		VisionOSPlatform.classify_input_source(VisionOSPlatform.ACCESSORY_PROFILE, true, false),
		VisionOSPlatform.InputSource.NONE,
		"An accessory missing its grip pose is not usable"
	)
	assert_eq(
		VisionOSPlatform.classify_input_source(VisionOSPlatform.ACCESSORY_PROFILE, false, true),
		VisionOSPlatform.InputSource.NONE,
		"An accessory missing its aim pose is not usable"
	)


func test_classify_optical_hand_accepts_single_pose() -> void:
	assert_eq(
		VisionOSPlatform.classify_input_source(VisionOSPlatform.OPTICAL_PROFILE, true, true),
		VisionOSPlatform.InputSource.OPTICAL_HAND,
		"Optical hands drive the saber"
	)
	assert_eq(
		VisionOSPlatform.classify_input_source(VisionOSPlatform.OPTICAL_PROFILE, true, false),
		VisionOSPlatform.InputSource.OPTICAL_HAND,
		"A hand with only an aim pose is still an optical hand"
	)
	assert_eq(
		VisionOSPlatform.classify_input_source(VisionOSPlatform.OPTICAL_PROFILE, false, true),
		VisionOSPlatform.InputSource.OPTICAL_HAND,
		"A hand with only a palm pose is still an optical hand"
	)


func test_classify_untracked_and_unknown_profiles() -> void:
	assert_eq(
		VisionOSPlatform.classify_input_source(VisionOSPlatform.ACCESSORY_PROFILE, false, false),
		VisionOSPlatform.InputSource.NONE,
		"An accessory with no poses at all is untracked"
	)
	assert_eq(
		VisionOSPlatform.classify_input_source(VisionOSPlatform.OPTICAL_PROFILE, false, false),
		VisionOSPlatform.InputSource.NONE,
		"A hand with no poses at all is untracked"
	)
	assert_eq(
		VisionOSPlatform.classify_input_source("", true, true),
		VisionOSPlatform.InputSource.NONE,
		"A tracker with no profile yet is not usable"
	)
	assert_eq(
		VisionOSPlatform.classify_input_source("openxr_touch_controller", true, true),
		VisionOSPlatform.InputSource.NONE,
		"An OpenXR profile never classifies as a visionOS source"
	)


func test_near_plane_scales_with_world_scale() -> void:
	assert_eq(
		VisionOSPlatform.near_plane_for_world_scale(1.0, 0.05),
		VisionOSPlatform.MIN_PHYSICAL_NEAR_PLANE_M,
		"A too-close near plane is pushed out to the platform minimum"
	)
	assert_eq(
		VisionOSPlatform.near_plane_for_world_scale(2.0, 0.05),
		VisionOSPlatform.MIN_PHYSICAL_NEAR_PLANE_M * 2.0,
		"Doubling world scale doubles the engine-unit near plane"
	)
	assert_eq(
		VisionOSPlatform.near_plane_for_world_scale(0.5, 0.05),
		VisionOSPlatform.MIN_PHYSICAL_NEAR_PLANE_M * 0.5,
		"Halving world scale halves the engine-unit near plane"
	)


func test_near_plane_never_pulls_an_existing_near_closer() -> void:
	assert_eq(
		VisionOSPlatform.near_plane_for_world_scale(1.0, 0.5),
		0.5,
		"A project that already pushes the near plane out keeps its value"
	)
	assert_eq(
		VisionOSPlatform.near_plane_for_world_scale(0.0, 0.25),
		0.25,
		"A degenerate world scale cannot collapse the near plane"
	)


func test_immersion_style_round_trips_with_the_passthrough_setting() -> void:
	assert_eq(
		VisionOSPlatform.style_for_passthrough(false),
		VisionOSPlatform.ImmersionStyle.FULL,
		"Passthrough off means fully immersive"
	)
	assert_eq(
		VisionOSPlatform.style_for_passthrough(true),
		VisionOSPlatform.ImmersionStyle.MIXED,
		"Passthrough on means mixed immersion"
	)
	assert_false(
		VisionOSPlatform.style_shows_passthrough(VisionOSPlatform.ImmersionStyle.FULL),
		"Full immersion hides the room"
	)
	assert_true(
		VisionOSPlatform.style_shows_passthrough(VisionOSPlatform.ImmersionStyle.MIXED),
		"Mixed immersion shows the room"
	)
	assert_true(
		VisionOSPlatform.style_shows_passthrough(VisionOSPlatform.ImmersionStyle.PROGRESSIVE),
		"Progressive immersion shows the room"
	)


func test_immersion_style_values_match_the_native_enum() -> void:
	# The exporter and VisionOSXRInterface both use these integers directly.
	assert_eq(int(VisionOSPlatform.ImmersionStyle.FULL), 0, "Full is 0")
	assert_eq(int(VisionOSPlatform.ImmersionStyle.MIXED), 1, "Mixed is 1")
	assert_eq(int(VisionOSPlatform.ImmersionStyle.PROGRESSIVE), 2, "Progressive is 2")


func test_settings_scopes_saber_offsets_per_platform() -> void:
	var native: bool = VisionOSPlatform.is_native_platform()
	for key: String in VisionOSPlatform.PLATFORM_SCOPED_KEYS:
		var expected: String = (VisionOSPlatform.SCOPED_KEY_PREFIX + key) if native else key
		assert_eq(VisionOSPlatform.config_key(key), expected, "Saber offsets are scoped per platform")
		# Settings must not diverge from the policy it delegates to.
		assert_eq(Settings.config_key(key), expected, "Settings delegates to the platform policy")
	# Everything else stays on the shared key so existing configs keep working.
	for key: String in ["visionos_passthrough", "glare", "cube_cuts_falloff"]:
		assert_eq(VisionOSPlatform.config_key(key), key, "Unscoped settings keep their key")


## Regression test for a black-screen bug: `render_target_size_multiplier` is an
## OpenXR-only property, so assigning it to the visionOS interface raised a
## GDScript error that aborted XR bootstrap before `use_xr` was ever set. The
## viewport then rendered with no XR target and the headset showed nothing.
func test_render_quality_skipped_unless_dynamic_quality_enabled() -> void:
	assert_eq(
		VisionOSPlatform.resolve_render_quality(1.5, false, 2.0),
		VisionOSPlatform.SKIP_RENDER_QUALITY,
		"The native setter hard-fails when dynamic render quality is disabled"
	)
	assert_eq(
		VisionOSPlatform.resolve_render_quality(1.5, true, 2.0),
		1.5,
		"An opted-in project applies the requested scale"
	)


func test_render_quality_never_exceeds_configured_maximum() -> void:
	# The native setter hard-fails above the project's maximum, so clamp instead.
	assert_eq(
		VisionOSPlatform.resolve_render_quality(2.5, true, 1.5),
		1.5,
		"Requests above the maximum are clamped to it"
	)
	for bad_scale: float in [0.0, -1.0, NAN, INF]:
		assert_eq(
			VisionOSPlatform.resolve_render_quality(bad_scale, true, 1.5),
			VisionOSPlatform.SKIP_RENDER_QUALITY,
			"A nonsensical render scale is ignored rather than pushed at the compositor"
		)
	assert_eq(
		VisionOSPlatform.resolve_render_quality(1.5, true, 0.0),
		VisionOSPlatform.SKIP_RENDER_QUALITY,
		"A missing maximum leaves the compositor default alone"
	)


## Regression test for an unreachable menu: visionOS reports an identity head
## pose for its first frames, and recentering against it shifted the rig about a
## metre, leaving world-anchored UI too close to read.
func test_head_pose_validity_rejects_the_identity_pose() -> void:
	assert_false(VisionOSPlatform.is_head_pose_valid(0.0), "An identity pose is not tracked")
	assert_false(VisionOSPlatform.is_head_pose_valid(0.5), "The threshold itself is not tracked")
	assert_true(VisionOSPlatform.is_head_pose_valid(1.7), "A standing head pose is tracked")
	assert_true(VisionOSPlatform.is_head_pose_valid(0.9), "A seated head pose is still tracked")


func test_upper_limb_visibility_follows_the_active_input_source() -> void:
	# These integers are passed straight to VisionOSXRInterface.upper_limb_visibility.
	assert_eq(int(VisionOSPlatform.Visibility.AUTOMATIC), 0, "Automatic is 0")
	assert_eq(int(VisionOSPlatform.Visibility.VISIBLE), 1, "Visible is 1")
	assert_eq(int(VisionOSPlatform.Visibility.HIDDEN), 2, "Hidden is 2")
	var optical := VisionOSPlatform.InputSource.OPTICAL_HAND
	var accessory := VisionOSPlatform.InputSource.SPATIAL_CONTROLLER
	var none := VisionOSPlatform.InputSource.NONE
	assert_eq(
		int(VisionOSPlatform.resolve_upper_limb_visibility(optical, optical)),
		int(VisionOSPlatform.Visibility.VISIBLE),
		"Optical hands stay visible because the hand is the input device"
	)
	assert_eq(
		int(VisionOSPlatform.resolve_upper_limb_visibility(accessory, accessory)),
		int(VisionOSPlatform.Visibility.HIDDEN),
		"Held controllers hide the composited hands"
	)
	assert_eq(
		int(VisionOSPlatform.resolve_upper_limb_visibility(optical, accessory)),
		int(VisionOSPlatform.Visibility.HIDDEN),
		"One controller is enough to hide the overlay"
	)
	assert_eq(
		int(VisionOSPlatform.resolve_upper_limb_visibility(none, none)),
		int(VisionOSPlatform.Visibility.VISIBLE),
		"Untracked hands fall back to visible rather than hiding the wearer's hands"
	)


func test_render_target_readiness_rejects_unpublished_target() -> void:
	assert_false(
		VisionOSPlatform.is_render_target_ready(Vector2.ZERO),
		"A zero target means the compositor has not published a size yet"
	)
	assert_false(
		VisionOSPlatform.is_render_target_ready(Vector2(1920.0, 0.0)),
		"A target is only usable once both dimensions are real"
	)
	assert_true(
		VisionOSPlatform.is_render_target_ready(Vector2(1920.0, 1824.0)),
		"A fully published target is ready for pipeline creation"
	)


func test_warmup_frames_are_longer_on_visionos() -> void:
	assert_eq(
		VisionOSPlatform.warmup_frames(false),
		VisionOSPlatform.DEFAULT_WARMUP_FRAMES,
		"Other platforms keep their original warm-up length"
	)
	assert_true(
		VisionOSPlatform.warmup_frames(true) > VisionOSPlatform.warmup_frames(false),
		"visionOS needs longer to compile its Metal pipelines"
	)


func test_saber_offset_default_corrects_only_visionos() -> void:
	var expected := VisionOSPlatform.SABER_ROT_CORRECTION_DEG \
		if VisionOSPlatform.is_native_platform() else Vector3.ZERO
	assert_eq(
		VisionOSPlatform.default_saber_offset_rot(),
		expected,
		"Only visionOS ships a non-zero saber alignment correction"
	)
	assert_eq(
		VisionOSPlatform.SABER_ROT_CORRECTION_DEG,
		Vector3(180.0, 0.0, 0.0),
		"The correction flips the blade back out of the fist"
	)


func test_simulator_adapter_detected_by_name() -> void:
	assert_true(
		VisionOSPlatform.is_simulator_adapter("Apple xrOS simulator GPU (Apple2)"),
		"The visionOS simulator names itself in the Metal adapter string"
	)
	assert_false(
		VisionOSPlatform.is_simulator_adapter("Apple M2 GPU (Apple8)"),
		"Real silicon must not be mistaken for the simulator"
	)


func test_msaa_disabled_only_on_simulator() -> void:
	assert_eq(
		VisionOSPlatform.resolve_msaa_3d(2, "Apple xrOS simulator GPU (Apple2)"),
		VisionOSPlatform.MSAA_DISABLED,
		"The simulator GPU cannot allocate multisampled array textures"
	)
	assert_eq(
		VisionOSPlatform.resolve_msaa_3d(2, "Apple Vision Pro GPU (Apple9)"),
		2,
		"Hardware keeps the configured MSAA level"
	)
