#!/bin/bash

set -euo pipefail

if [[ $# -lt 3 ]]; then
    echo "Usage: $0 <simulator-udid> <output-directory> <app-path>"
    exit 64
fi

simulator_udid="$1"
output_directory="$2"
app_path="$3"
bundle_identifier="net.montpetit.thaisheet.dev"
capture_tmp_dir="$(mktemp -d /private/tmp/thaisheet-screenshots.XXXXXX)"

cleanup() {
    rm -rf "$capture_tmp_dir"
}
trap cleanup EXIT

scenarios=(
    "vowels:01-vowels"
    "vowels-blurred:02-vowels-practice"
    "consonant-details:03-consonant-details"
    "tones:04-tones"
    "flashcard-completed:05-flashcard-completed"
    "progress:06-progress"
)

mkdir -p "$output_directory"

xcrun simctl boot "$simulator_udid" 2>/dev/null || true
xcrun simctl bootstatus "$simulator_udid" -b
xcrun simctl install "$simulator_udid" "$app_path"
xcrun simctl status_bar "$simulator_udid" override \
    --time 9:41 \
    --batteryState charged \
    --batteryLevel 100 \
    --wifiBars 3 \
    --cellularBars 4

for entry in "${scenarios[@]}"; do
    scenario="${entry%%:*}"
    filename="${entry#*:}"
    png_path="$capture_tmp_dir/$filename.png"
    jpg_path="$output_directory/$filename.jpg"

    xcrun simctl terminate "$simulator_udid" "$bundle_identifier" 2>/dev/null || true
    xcrun simctl launch "$simulator_udid" "$bundle_identifier" \
        -screenshotScenario "$scenario" \
        -fc_useIntelligentSelection NO \
        -AppleLanguages '(en)' \
        -AppleLocale en_US >/dev/null
    sleep 3
    xcrun simctl io "$simulator_udid" screenshot "$png_path"
    sips -s format jpeg -s formatOptions best "$png_path" --out "$jpg_path" >/dev/null
    echo "Captured $jpg_path"
done
