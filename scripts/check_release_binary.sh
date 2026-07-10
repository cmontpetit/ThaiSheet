#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 /path/to/ThaiSheet.app-or-binary" >&2
  exit 2
fi

input="$1"
binary="$input"

if [[ -d "$input" ]]; then
  binary="$input/ThaiSheet"

  echo "Checking Info.plist..."
  /usr/bin/plutil -extract CFBundleIdentifier raw "$input/Info.plist" | grep -qx "net.montpetit.thaisheet"
  /usr/bin/plutil -extract ITSAppUsesNonExemptEncryption raw "$input/Info.plist" | grep -qx "false"
fi

if [[ ! -f "$binary" ]]; then
  echo "Binary not found: $binary" >&2
  exit 2
fi

echo "Checking for LLVM coverage/profile sections..."
if /usr/bin/otool -l "$binary" | /usr/bin/grep -Eq '(__LLVM|__llvm_prf|__llvm_cov)'; then
  echo "Release binary contains LLVM coverage/profile sections." >&2
  exit 1
fi

if /usr/bin/strings "$binary" | /usr/bin/grep -Eq '(LLVM_PROFILE|default\.profraw|__LLVM_PROFILE)'; then
  echo "Release binary contains LLVM profiling strings." >&2
  exit 1
fi

echo "Release binary checks passed."
