#!/bin/bash
#
# Captures raw App Store screenshots for one set in scripts/app_store_screenshots.json.
# Frame and caption them afterwards with scripts/frame_app_store_screenshots.py.
#
#   sets: iphone (6.9" simulator), ipad (13" simulator),
#         duo-open / duo-closed (iPhone Duo; set the hinge pose first)
#   display-id: required on iPhone Duo, which has two displays. Run
#         `xcrun simctl io <udid> screenshot x.png` once to list them.
#   CAPTURE_DELAY: seconds to wait after launch (default 6)

set -euo pipefail

if [[ $# -lt 4 ]]; then
    echo "Usage: $0 <simulator-udid> <output-directory> <debug-app-path> <set> [display-id]"
    exit 64
fi

simulator_udid="$1"
output_directory="$2"
app_path="$3"
set_name="$4"
display_id="${5:-}"
delay="${CAPTURE_DELAY:-6}"
bundle_identifier="net.montpetit.thaisheet.dev"
config="$(cd "$(dirname "$0")" && pwd)/app_store_screenshots.json"

scenarios=()
while IFS= read -r line; do scenarios+=("$line"); done < <(
    python3 -c 'import json,sys; [print(s["scenario"]) for s in json.load(open(sys.argv[1]))["sets"][sys.argv[2]]["shots"]]' \
        "$config" "$set_name"
)

display_args=()
[[ -n "$display_id" ]] && display_args=(--display="$display_id")

mkdir -p "$output_directory"

xcrun simctl boot "$simulator_udid" 2>/dev/null || true
xcrun simctl bootstatus "$simulator_udid" -b >/dev/null
xcrun simctl install "$simulator_udid" "$app_path"
# 9:41 local time; simctl only accepts ISO dates with fractional seconds and
# a colon in the UTC offset
utc_offset="$(date -j -f %Y-%m-%dT%H:%M 2026-01-13T09:41 +%z)"
xcrun simctl status_bar "$simulator_udid" override \
    --time "2026-01-13T09:41:00.000${utc_offset:0:3}:${utc_offset:3:2}" \
    --batteryState charged \
    --batteryLevel 100 \
    --wifiBars 3 \
    --cellularBars 4

index=0
for scenario in "${scenarios[@]}"; do
    index=$((index + 1))
    png_path="$output_directory/$(printf '%02d' "$index")-$scenario.png"

    xcrun simctl terminate "$simulator_udid" "$bundle_identifier" 2>/dev/null || true
    xcrun simctl launch "$simulator_udid" "$bundle_identifier" \
        -screenshotScenario "$scenario" \
        -fc_useIntelligentSelection NO \
        -fc_hasSeenReferenceInfo '<true/>' \
        -AppleLanguages '(en)' \
        -AppleLocale en_US >/dev/null
    sleep "$delay"
    xcrun simctl io "$simulator_udid" screenshot ${display_args[@]+"${display_args[@]}"} "$png_path" >/dev/null 2>&1
    echo "Captured $png_path"
done
