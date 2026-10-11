#!/usr/bin/env bash
set -u

root=$(cd "$(dirname "$0")/.." && pwd -P) || exit 1
cd "$root" || exit 1

failures=0
for shell in bash zsh; do
    if ! command -v "$shell" >/dev/null 2>&1; then
        printf 'skip: %s is not installed\n' "$shell"
        continue
    fi
    for test_file in "$root"/tests/test_*.sh; do
        printf '== %s %s\n' "$shell" "${test_file#"$root"/}"
        if ! "$shell" "$test_file"; then
            failures=$((failures + 1))
        fi
    done
done

if [[ "$failures" -ne 0 ]]; then
    printf '%s test run(s) failed\n' "$failures" >&2
    exit 1
fi
printf 'all tests passed\n'
