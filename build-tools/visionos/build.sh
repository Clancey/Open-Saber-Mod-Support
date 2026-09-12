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
# The hashes may be overridden when developing the engine itself, which is a
# deliberate act: an unpinned build is only as trustworthy as the engine you
# can name. Leave them unset for reproducible builds.
ENGINE_COMMIT="643c5348568a4a227bdc5119d6c8a0074fc3c9be"
ENGINE_SDK_DIR="${GODOT_VISIONOS_SDK:-/Users/clancey/Projects/copilot-worktrees/godot-vision/clancey-shiny-fiesta/bin/visionos-sdk/${ENGINE_COMMIT}}"
EDITOR_SHA256="${GODOT_VISIONOS_EDITOR_SHA256:-60e435163f95a3dfed5af0a2a022f16b8f058e4aa2f7e99ee985ed13ad0f8fd0}"
TEMPLATE_SHA256="${GODOT_VISIONOS_TEMPLATE_SHA256:-7a0d722034aec6d1b3927b6713f74011e00215a270d1800b37785106fa4c01a4}"

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
REPO_TEMPLATE="$PROJECT_ROOT/build-tools/visionos/visionos.zip"
# The visionOS export presets hardcode `custom_template` to the repo template,
# so pointing the exporter at a different engine means staging that file into
# this exact path. GODOT_VISIONOS_TEMPLATE exists so an exploratory engine build
# can be exercised without committing it; the working tree is always restored,
# including on failure, so a build can never silently leave a patched template
# behind for the next one to pick up.
TEMPLATE="${GODOT_VISIONOS_TEMPLATE:-$REPO_TEMPLATE}"
# Which engine the shipped binary must prove it linked. Overriding the template
# without also declaring its commit would make the post-build gate assert the
# pinned identity against a deliberately different engine.
EXPECTED_ENGINE_COMMIT="${GODOT_VISIONOS_ENGINE_COMMIT:-$ENGINE_COMMIT}"
ENGINE_MARKER="${GODOT_VISIONOS_ENGINE_MARKER:-}"
TEMPLATE_BACKUP=""
EXPORT_LOG=""

cleanup() {
	if [[ -n "$TEMPLATE_BACKUP" ]]; then
		chmod u+w "$REPO_TEMPLATE" 2>/dev/null || true
		cp "$TEMPLATE_BACKUP" "$REPO_TEMPLATE"
		chmod a-w "$REPO_TEMPLATE" 2>/dev/null || true
		rm -f "$TEMPLATE_BACKUP"
		echo "restored the repository export template"
	fi
	[[ -n "$EXPORT_LOG" ]] && rm -f "$EXPORT_LOG"
	return 0
}
trap cleanup EXIT

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

# A pinned template hash proves only which file was *available*, never which
# engine the linker actually consumed -- export_presets.cfg hardcodes the
# template path, so those can diverge silently. Godot embeds its build commit in
# the binary, so this reads engine identity out of the shipped artifact itself.
#
# Two limits of the embedded commit, both measured rather than assumed:
#   1. It is not the only 40-char hex string in the binary. harfbuzz, embree and
#      brotli all carry hex-looking tables, so identity must be tested by
#      membership of a specific commit -- never by printing "the hash".
#   2. It records the commit that core/version_hash.gen.cpp was *compiled* at,
#      not the commit whose source is in the binary. On an incremental build
#      those diverge: we have observed a slice containing new code while
#      reporting the pre-fix commit, and the same mechanism can report the new
#      commit while the fix itself failed to recompile.
# GODOT_VISIONOS_ENGINE_MARKER closes (2) by asserting a string that exists only
# in the overridden engine's source, which observes the code rather than the
# build's self-report.
verify_linked_engine() {
	local binary="$1" expected="$2" hashes
	hashes="$(strings "$binary" 2>/dev/null | grep -oE '\b[0-9a-f]{40}\b' | sort -u)"
	if ! grep -qFx "$expected" <<<"$hashes"; then
		echo "error: shipped binary does not embed the expected engine commit" >&2
		echo "  binary:   $binary" >&2
		echo "  expected: $expected" >&2
		echo "  embedded: $(tr '\n' ' ' <<<"$hashes")" >&2
		exit 1
	fi
	# Negative control. Asserting only that the wanted commit is present is a
	# test that cannot fail usefully: an override that silently fell back to the
	# pinned engine would still pass. Require the identity we must NOT see to be
	# absent as well.
	if [[ "$expected" != "$ENGINE_COMMIT" ]] && grep -qFx "$ENGINE_COMMIT" <<<"$hashes"; then
		echo "error: shipped binary embeds pinned engine $ENGINE_COMMIT despite an override" >&2
		echo "  the export did not consume $TEMPLATE" >&2
		exit 1
	fi
	if [[ -n "$ENGINE_MARKER" ]]; then
		# grep -q exits on first match, which kills the producer with SIGPIPE;
		# under `set -o pipefail` that reports 141 and the check fails on a
		# binary that actually contains the marker. Count instead, so the
		# producer always runs to completion.
		local marker_hits
		marker_hits="$(strings "$binary" 2>/dev/null | grep -cF "$ENGINE_MARKER" || true)"
		if [[ "${marker_hits:-0}" -eq 0 ]]; then
			echo "error: shipped binary embeds $expected but not the code that commit introduced" >&2
			echo "  missing marker: $ENGINE_MARKER" >&2
			echo "  the version hash recompiled while the changed source did not." >&2
			exit 1
		fi
		echo "ok: engine marker present ($ENGINE_MARKER)"
	fi
	echo "ok: linked engine $expected (verified in shipped binary)"
}

echo "== verifying pinned engine (commit $ENGINE_COMMIT) =="
verify_hash "editor" "$GODOT" "$EDITOR_SHA256"
verify_hash "export template" "$TEMPLATE" "$TEMPLATE_SHA256"

if [[ "$TEMPLATE" != "$REPO_TEMPLATE" ]]; then
	echo "== staging alternate export template =="
	echo "  $TEMPLATE"
	TEMPLATE_BACKUP="$(mktemp -t opensaber-visionos-template)"
	cp "$REPO_TEMPLATE" "$TEMPLATE_BACKUP"
	chmod u+w "$REPO_TEMPLATE"
	cp "$TEMPLATE" "$REPO_TEMPLATE"
fi

cd "$PROJECT_ROOT"

echo
echo "== importing =="
"$GODOT" --headless --xr-mode off --path . --import

echo
echo "== tests =="
# This test already fails on godot-4-port without any visionOS change (verified
# at a28677e: 48 passed, 1 failed), so it is allowlisted by name rather than by
# ignoring the exit code, and any *other* failure still stops the build.
KNOWN_FAILURES=(
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
	for known in "${KNOWN_FAILURES[@]}"; do
		[[ "$test_name" == "$known" ]] && allowed=1 && break
	done
	if [[ "$allowed" -eq 0 ]]; then
		echo "error: unexpected test failure: $test_name" >&2
		UNEXPECTED=1
	fi
done < <(grep "^FAIL " "$TEST_LOG" || true)

if grep -qE "Parse Error|Compile Error|Failed to instantiate an autoload" "$TEST_LOG"; then
	echo "error: a script or scene failed to load; see the test log above" >&2
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
verify_linked_engine "$EXECUTABLE" "$EXPECTED_ENGINE_COMMIT"
shasum -a 256 "$EXECUTABLE" "$APP/Info.plist"
find "$APP" -name "*.pck" -exec shasum -a 256 {} \;
dwarfdump --uuid "$EXECUTABLE"

if [[ "$TARGET" == "device" ]]; then
	codesign --verify --deep --strict --verbose=2 "$APP"
else
	echo "note: simulator build, code signature not verified (simulator builds are not device evidence)"
fi
