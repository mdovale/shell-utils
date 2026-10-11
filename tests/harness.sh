# Sourced by tests/test_*.sh. Those files are executed, not sourced.

SHELL_UTILS_ROOT=$(cd "$(dirname "$0")/.." && pwd -P) || exit 1

checks=0
failures=0

ok() {
    checks=$((checks + 1))
}

bad() {
    failures=$((failures + 1))
    printf 'FAIL: %s\n' "$1" >&2
}

eq() {
    local actual="$1"
    local expected="$2"
    local msg="$3"
    if [[ "$actual" == "$expected" ]]; then
        ok
    else
        bad "$msg"
        printf '  expected: [%s]\n  actual:   [%s]\n' "$expected" "$actual" >&2
    fi
}

status_is() {
    local expected="$1"
    local actual
    shift
    "$@"
    actual=$?
    if [[ "$actual" -eq "$expected" ]]; then
        ok
    else
        bad "$* -> status ${actual}, expected ${expected}"
    fi
}

contains() {
    local haystack="$1"
    local needle="$2"
    local msg="$3"
    case "$haystack" in
        *"$needle"*) ok ;;
        *)
            bad "$msg"
            printf '  missing: [%s]\n' "$needle" >&2
            ;;
    esac
}

not_contains() {
    local haystack="$1"
    local needle="$2"
    local msg="$3"
    case "$haystack" in
        *"$needle"*)
            bad "$msg"
            printf '  unexpectedly found: [%s]\n' "$needle" >&2
            ;;
        *) ok ;;
    esac
}

is_function() {
    local name="$1"
    if [[ -n ${ZSH_VERSION:-} ]]; then
        case $(whence -w "$name" 2>/dev/null) in
            *"function"*) ok ;;
            *) bad "${name} is not a function" ;;
        esac
    elif [[ $(type -t "$name" 2>/dev/null) == "function" ]]; then
        ok
    else
        bad "${name} is not a function"
    fi
}

finish() {
    if [[ "$failures" -eq 0 ]]; then
        printf 'ok (%s checks)\n' "$checks"
        exit 0
    fi
    printf '%s failed, %s checks passed\n' "$failures" "$checks" >&2
    exit 1
}

set -u
