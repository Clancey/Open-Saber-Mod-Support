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
