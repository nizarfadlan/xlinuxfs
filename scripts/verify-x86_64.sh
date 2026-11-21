#!/bin/bash
# Verify the architectures present in a built xlinuxfs app and liblkl.a.
#
# Usage:
#   bash scripts/verify-x86_64.sh <path/to/xlinuxfs.app> [expected-app-archs]
#
# expected-app-archs defaults to "x86_64". Pass "arm64 x86_64" to check a
# universal build instead. The app binary and the embedded lklfuse.appex
# must contain exactly the expected architectures. libs/liblkl.a, when it
# exists, must contain x86_64 (the prebuild script always produces a
# universal archive, so a missing arm64 slice there is also reported).
#
# macOS only: uses `lipo`, which does not exist on Linux.
set -euo pipefail

app="${1:?Usage: bash scripts/verify-x86_64.sh <path/to/xlinuxfs.app> [expected-archs]}"
expected="${2:-x86_64}"
root="$(cd "$(dirname "$0")/.." && pwd)"

normalise() {
    # Sort one architecture list so "x86_64 arm64" and "arm64 x86_64" compare equal.
    printf '%s' "$1" | tr ' ' '\n' | sort | tr '\n' ' ' | sed 's/ *$//'
}

check_exact() {
    local file="$1" want="$2" have
    if [[ ! -f "$file" ]]; then
        printf 'FAIL: missing file: %s\n' "$file" >&2
        exit 1
    fi
    have="$(lipo -archs "$file")"
    printf '%s: %s\n' "$file" "$have"
    if [[ "$(normalise "$have")" != "$(normalise "$want")" ]]; then
        printf 'FAIL: %s has architectures [%s], expected [%s]\n' "$file" "$have" "$want" >&2
        exit 1
    fi
}

check_contains() {
    local file="$1" want="$2" have
    if [[ ! -f "$file" ]]; then
        printf 'SKIP: %s not present (run scripts/build-liblkl.sh first)\n' "$file"
        return 0
    fi
    have="$(lipo -archs "$file")"
    printf '%s: %s\n' "$file" "$have"
    case " $have " in
        *" $want "*) ;;
        *)
            printf 'FAIL: %s lacks architecture %s (has [%s])\n' "$file" "$want" "$have" >&2
            exit 1
            ;;
    esac
}

if [[ ! -d "$app" ]]; then
    printf 'FAIL: app not found: %s\n' "$app" >&2
    exit 1
fi

check_exact "$app/Contents/MacOS/xlinuxfs" "$expected"

appex="$(find "$app" -name 'lklfuse.appex' -print -quit)"
if [[ -z "$appex" ]]; then
    printf 'FAIL: lklfuse.appex not found inside %s\n' "$app" >&2
    exit 1
fi
check_exact "$appex/Contents/MacOS/lklfuse" "$expected"

# liblkl.a is built universal by scripts/prebuild-lkl.py, so both slices
# are expected whenever the archive is present.
if [[ -f "$root/libs/liblkl.a" ]]; then
    check_exact "$root/libs/liblkl.a" "arm64 x86_64"
else
    check_contains "$root/libs/liblkl.a" "x86_64"
fi

printf 'PASS: xlinuxfs.app matches [%s]; liblkl.a contains x86_64\n' "$expected"
