#!/usr/bin/env bash
#
# Builds the native visionOS port of Open Saber with the pinned engine.
#
# The whole point of this script is that a visionOS artifact is only meaningful
# if you can say which engine produced it. It refuses to run against an editor
# or export template whose hash does not match the pin below, and it keeps
# device and simulator outputs in separate directories so a simulator build can
# never be mistaken for something that ran on a headset.
#
# Usage:
#   build-tools/visionos/build.sh [device|simulator] [debug|release]
#
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Pinned engine: Clancey/godot @ clancey-visionos.
ENGINE_COMMIT="643c5348568a4a227bdc5119d6c8a0074fc3c9be"
ENGINE_SDK_DIR="${GODOT_VISIONOS_SDK:-/Users/clancey/Projects/copilot-worktrees/godot-vision/clancey-shiny-fiesta/bin/visionos-sdk/${ENGINE_COMMIT}}"
EDITOR_SHA256="60e435163f95a3dfed5af0a2a022f16b8f058e4aa2f7e99ee985ed13ad0f8fd0"
TEMPLATE_SHA256="7a0d722034aec6d1b3927b6713f74011e00215a270d1800b37785106fa4c01a4"

TARGET="${1:-device}"
BUILD_TYPE="${2:-debug}"

# Apple team used for app signing. The export preset signs the GDExtension
# dylibs separately with an exact certificate hash.
DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-6TMAULLKT8}"

case "$TARGET" in
	device)
		PRESET="visionOS"
		EXPORT_DIR="build/visionos"
		XCODE_SDK="xros"
		XCODE_DESTINATION="generic/platform=visionOS"
		;;
	simulator)
		PRESET="visionOS Simulator"
		EXPORT_DIR="build/visionos-simulator"
		XCODE_SDK="xrsimulator"
		XCODE_DESTINATION="generic/platform=visionOS Simulator"
		;;
	*)
		echo "error: target must be 'device' or 'simulator', got '$TARGET'" >&2
		exit 2
		;;
esac

case "$BUILD_TYPE" in
	debug)
		EXPORT_FLAG="--export-debug"
		XCODE_CONFIG="Debug"
		XCODE_SIGN_IDENTITY="Apple Development"
		;;
	release)
		EXPORT_FLAG="--export-release"
		XCODE_CONFIG="Release"
		XCODE_SIGN_IDENTITY="Apple Distribution"
		;;
	*)
		echo "error: build type must be 'debug' or 'release', got '$BUILD_TYPE'" >&2
		exit 2
		;;
esac

GODOT="$ENGINE_SDK_DIR/godot.macos.editor.arm64"
TEMPLATE="$PROJECT_ROOT/build-tools/visionos/visionos.zip"

verify_hash() {
	local label="$1" path="$2" expected="$3"
	if [[ ! -f "$path" ]]; then
		echo "error: $label missing at $path" >&2
		exit 1
	fi
	local actual
	actual="$(shasum -a 256 "$path" | cut -d' ' -f1)"
	if [[ "$actual" != "$expected" ]]; then
		echo "error: $label hash mismatch" >&2
		echo "  path:     $path" >&2
		echo "  expected: $expected" >&2
		echo "  actual:   $actual" >&2
		echo "The pinned engine is what makes this build reproducible. Refusing to continue." >&2
		exit 1
	fi
	echo "ok: $label $actual"
}

echo "== verifying pinned engine (commit $ENGINE_COMMIT) =="
verify_hash "editor" "$GODOT" "$EDITOR_SHA256"
verify_hash "export template" "$TEMPLATE" "$TEMPLATE_SHA256"

cd "$PROJECT_ROOT"

echo
echo "== importing =="
"$GODOT" --headless --xr-mode off --path . --import

echo
echo "== tests =="
# The shipped Beat Saber / Golden maps are copyrighted and are not in the repo,
# so the four level-hash tests that need them fail on every clean clone. They are
# allowlisted by name rather than by ignoring the exit code, so any *other*
# failure still stops the build.
ENV_DEPENDENT_FAILURES=(
	"test_level_hash.test_level_hash_is_cached_on_map_info_and_empty_when_missing"
	"test_level_hash.test_song_key_format_and_matching"
	"test_level_hash.test_v2_level_hash_matches_reference"
	"test_level_hash.test_v4_level_hash_uses_beatmap_and_lightshow_files"
)
TEST_LOG="$(mktemp -t opensaber-visionos-tests)"
set +e
"$GODOT" --headless --xr-mode off --path . --script res://tests/run.gd 2>&1 | tee "$TEST_LOG"
set -e

UNEXPECTED=0
while read -r _ test_name; do
	[[ -z "$test_name" ]] && continue
	allowed=0
	for known in "${ENV_DEPENDENT_FAILURES[@]}"; do
		[[ "$test_name" == "$known" ]] && allowed=1 && break
	done
	if [[ "$allowed" -eq 0 ]]; then
		echo "error: unexpected test failure: $test_name" >&2
		UNEXPECTED=1
	fi
done < <(grep "^FAIL " "$TEST_LOG" || true)

if grep -qE "Parse Error|Compile Error|Failed to instantiate an autoload" "$TEST_LOG"; then
	echo "error: a script failed to compile; see the test log above" >&2
	UNEXPECTED=1
fi
rm -f "$TEST_LOG"
[[ "$UNEXPECTED" -eq 0 ]] || exit 1

echo
echo "== exporting '$PRESET' ($BUILD_TYPE) =="
mkdir -p "$EXPORT_DIR"
# Godot can exit 0 with script errors on stderr, so the export log is captured
# and scanned rather than trusted.
EXPORT_LOG="$(mktemp -t opensaber-visionos-export)"
trap 'rm -f "$EXPORT_LOG"' EXIT
set +e
"$GODOT" --headless --xr-mode off --path . "$EXPORT_FLAG" "$PRESET" "$EXPORT_DIR/OpenSaber.xcodeproj" 2>&1 | tee "$EXPORT_LOG"
EXPORT_STATUS="${PIPESTATUS[0]}"
set -e
if [[ "$EXPORT_STATUS" -ne 0 ]]; then
	echo "error: export failed with status $EXPORT_STATUS" >&2
	exit 1
fi
if grep -qE "SCRIPT ERROR|Parse Error|Failed to load|Cannot open file" "$EXPORT_LOG"; then
	echo "error: export log contains errors; the artifact is not trustworthy" >&2
	exit 1
fi

echo
echo "== xcodebuild ($XCODE_SDK / $XCODE_CONFIG) =="
# Godot writes a manual-signing project, but the only profile that covers this
# bundle id for the team is Xcode-managed, so app signing is switched to
# automatic here. The export step still signs the GDExtension dylibs with the
# exact certificate hash from the preset, because "Apple Development" alone is
# ambiguous on this machine.
xcodebuild \
	-project "$EXPORT_DIR/OpenSaber.xcodeproj" \
	-scheme "OpenSaber" \
	-configuration "$XCODE_CONFIG" \
	-sdk "$XCODE_SDK" \
	-destination "$XCODE_DESTINATION" \
	-derivedDataPath "$EXPORT_DIR/DerivedData" \
	-allowProvisioningUpdates \
	CODE_SIGN_STYLE=Automatic \
	DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM" \
	CODE_SIGN_IDENTITY="$XCODE_SIGN_IDENTITY" \
	PROVISIONING_PROFILE= \
	PROVISIONING_PROFILE_SPECIFIER= \
	build

APP="$(find "$EXPORT_DIR/DerivedData/Build/Products" -maxdepth 2 -name "*.app" -print -quit || true)"
if [[ -z "$APP" ]]; then
	echo "error: no .app produced under $EXPORT_DIR/DerivedData/Build/Products" >&2
	exit 1
fi

echo
echo "== artifact identity =="
echo "app: $APP"
echo "target: $TARGET ($XCODE_SDK)"
/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP/Info.plist"
/usr/libexec/PlistBuddy -c "Print :UIApplicationSceneManifest" "$APP/Info.plist" 2>/dev/null | grep -i immersion || true
EXECUTABLE="$APP/$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$APP/Info.plist")"
shasum -a 256 "$EXECUTABLE" "$APP/Info.plist"
find "$APP" -name "*.pck" -exec shasum -a 256 {} \;
dwarfdump --uuid "$EXECUTABLE"

if [[ "$TARGET" == "device" ]]; then
	codesign --verify --deep --strict --verbose=2 "$APP"
else
	echo "note: simulator build, code signature not verified (simulator builds are not device evidence)"
fi
