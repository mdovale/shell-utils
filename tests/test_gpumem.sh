. "$(cd "$(dirname "$0")" && pwd)/harness.sh"
# shellcheck disable=SC1091
. "$SHELL_UTILS_ROOT/init.sh"

tmp=$(mktemp -d) || exit 1
cleanup() {
    cd "$SHELL_UTILS_ROOT" || cd / || true
    rm -rf "$tmp"
}
trap cleanup EXIT

mkdir -p "$tmp/bin"
cat > "$tmp/bin/sysctl" << 'EOF'
#!/bin/sh
log=${GPUMEM_TEST_LOG:-}
memsize=${GPUMEM_TEST_MEMSIZE:-17179869184}
limit=${GPUMEM_TEST_LIMIT:-0}

if [ "$1" = "-n" ]; then
    case "$2" in
        hw.memsize)
            if [ "${GPUMEM_TEST_FAIL_MEMSIZE:-0}" = "1" ]; then
                exit 1
            fi
            printf '%s\n' "$memsize"
            ;;
        iogpu.wired_limit_mb)
            if [ "${GPUMEM_TEST_FAIL_KEY:-0}" = "1" ]; then
                exit 1
            fi
            printf '%s\n' "$limit"
            ;;
        *)
            exit 1
            ;;
    esac
    exit 0
fi

if [ "$1" = "-w" ]; then
    if [ -n "$log" ]; then
        printf '%s\n' "$2" >> "$log"
    fi
    exit 0
fi

exit 1
EOF
cat > "$tmp/bin/sudo" << 'EOF'
#!/bin/sh
log=${GPUMEM_TEST_LOG:-}
if [ "${GPUMEM_TEST_SUDO_FAIL:-0}" = "1" ]; then
    echo "sudo: denied" >&2
    exit 1
fi
if [ -n "$log" ]; then
    printf 'sudo %s\n' "$*" >> "$log"
fi
exec "$@"
EOF
chmod +x "$tmp/bin/sysctl" "$tmp/bin/sudo"

export PATH="$tmp/bin:$PATH"
export GPUMEM_TEST_LOG="$tmp/writes"
export GPUMEM_TEST_MEMSIZE=$((96 * 1024 * 1024 * 1024))
export GPUMEM_TEST_LIMIT=0
export GPUMEM_TEST_FAIL_KEY=0
export GPUMEM_TEST_FAIL_MEMSIZE=0
export GPUMEM_TEST_SUDO_FAIL=0
: > "$GPUMEM_TEST_LOG"

out=$(gpumem --help)
eq "$?" "0" "gpumem --help status"
contains "$out" "usage: gpumem" "gpumem help"
contains "$out" "GPUMEM_RESERVE_GB" "gpumem help mentions the reserve"
contains "$out" "iogpu.wired_limit_mb" "gpumem help names the sysctl"

out=$(gpumem help)
eq "$?" "0" "gpumem help status"
contains "$out" "usage: gpumem" "gpumem help word"

out=$(gpumem 2>&1)
eq "$?" "0" "gpumem status"
contains "$out" "Total memory : 96.0 GiB" "status prints total memory"
contains "$out" "macOS default (~75% of total)" "zero limit is the macOS default"
not_contains "$out" "sudo" "status does not mention sudo"
if [[ -s "$GPUMEM_TEST_LOG" ]]; then
    bad "status invoked sudo or sysctl -w"
else
    ok
fi

GPUMEM_TEST_LIMIT=12288
out=$(gpumem -s 2>&1)
eq "$?" "0" "gpumem -s status"
contains "$out" "GPU limit    : 12.0 GiB (12288 MB)" "prints an explicit limit"
GPUMEM_TEST_LIMIT=0

out=$(gpumem status 2>&1)
eq "$?" "0" "gpumem status word"
contains "$out" "macOS default" "status word reads the limit"

: > "$GPUMEM_TEST_LOG"
out=$(gpumem 12 2>&1)
eq "$?" "0" "gpumem 12 status"
contains "$out" "GPU limit    : 12.0 GiB (12288 MB)" "set prints the new limit"
contains "$(cat "$GPUMEM_TEST_LOG")" "sudo sysctl -w iogpu.wired_limit_mb=12288" "set goes through sudo"
contains "$(cat "$GPUMEM_TEST_LOG")" "iogpu.wired_limit_mb=12288" "set writes the sysctl"

: > "$GPUMEM_TEST_LOG"
out=$(gpumem -- 86 2>&1)
eq "$?" "0" "gpumem -- 86 status"
contains "$(cat "$GPUMEM_TEST_LOG")" "iogpu.wired_limit_mb=88064" "explicit size at the reserve boundary"

: > "$GPUMEM_TEST_LOG"
out=$(gpumem 08 2>&1)
eq "$?" "0" "leading zero is decimal"
contains "$(cat "$GPUMEM_TEST_LOG")" "iogpu.wired_limit_mb=8192" "08 means 8 GiB"

: > "$GPUMEM_TEST_LOG"
out=$(gpumem 87 2>&1)
eq "$?" "1" "over the reserve is refused"
contains "$out" "refusing 87 GiB; that leaves under 10 GiB for macOS (max allowed: 86 GiB)" "refuse message"
not_contains "$out" "Total memory" "refused set does not print a summary"
if [[ -s "$GPUMEM_TEST_LOG" ]]; then
    bad "refused set wrote the sysctl"
else
    ok
fi

: > "$GPUMEM_TEST_LOG"
out=$(gpumem max 2>&1)
eq "$?" "0" "gpumem max status"
contains "$(cat "$GPUMEM_TEST_LOG")" "iogpu.wired_limit_mb=88064" "max leaves the default 10 GiB"
contains "$out" "GPU limit    : 86.0 GiB (88064 MB)" "max prints the ceiling"

: > "$GPUMEM_TEST_LOG"
out=$(GPUMEM_RESERVE_GB=12 gpumem max 2>&1)
eq "$?" "0" "custom reserve status"
contains "$(cat "$GPUMEM_TEST_LOG")" "iogpu.wired_limit_mb=86016" "GPUMEM_RESERVE_GB overrides the reserve"
contains "$out" "GPU limit    : 84.0 GiB (86016 MB)" "custom reserve prints 84 GiB"

: > "$GPUMEM_TEST_LOG"
out=$(gpumem reset 2>&1)
eq "$?" "0" "gpumem reset status"
contains "$(cat "$GPUMEM_TEST_LOG")" "iogpu.wired_limit_mb=0" "reset writes 0"
contains "$out" "macOS default (~75% of total)" "reset reports the default"

: > "$GPUMEM_TEST_LOG"
out=$(gpumem 0 2>&1)
eq "$?" "0" "gpumem 0 status"
contains "$(cat "$GPUMEM_TEST_LOG")" "iogpu.wired_limit_mb=0" "0 restores the default"

GPUMEM_TEST_FAIL_KEY=1
out=$(gpumem 2>&1)
eq "$?" "1" "missing sysctl status"
contains "$out" "iogpu.wired_limit_mb" "names the missing sysctl"
contains "$out" "Apple Silicon and macOS 14+" "explains the requirement"
not_contains "$out" "Total memory" "missing sysctl prints no summary"
GPUMEM_TEST_FAIL_KEY=0

GPUMEM_TEST_FAIL_MEMSIZE=1
out=$(gpumem 2>&1)
eq "$?" "1" "missing memsize status"
contains "$out" "cannot read hw.memsize" "memsize failure"
GPUMEM_TEST_FAIL_MEMSIZE=0

GPUMEM_TEST_LIMIT="nope"
out=$(gpumem 2>&1)
eq "$?" "1" "non-numeric limit status"
contains "$out" "unexpected iogpu.wired_limit_mb" "rejects a non-numeric limit"
GPUMEM_TEST_LIMIT=0

: > "$GPUMEM_TEST_LOG"
GPUMEM_TEST_SUDO_FAIL=1
out=$(gpumem reset 2>&1)
eq "$?" "1" "sudo failure status"
contains "$out" "sudo: denied" "sudo failure is visible"
not_contains "$out" "Total memory" "sudo failure prints no summary"
GPUMEM_TEST_SUDO_FAIL=0

out=$(gpumem 6.5 2>&1)
eq "$?" "2" "fractional GiB status"
contains "$out" "invalid argument" "fractional GiB is rejected"

out=$(gpumem no 2>&1)
eq "$?" "2" "bad argument status"
contains "$out" "invalid argument: no" "names the bad argument"
contains "$out" "gpumem --help" "points at help"

status_is 2 gpumem --bogus
status_is 2 gpumem max extra

out=$(GPUMEM_RESERVE_GB=10gb gpumem 2>&1)
eq "$?" "2" "bad reserve status"
contains "$out" "GPUMEM_RESERVE_GB must be a non-negative integer" "bad reserve message"

GPUMEM_TEST_MEMSIZE=$((8 * 1024 * 1024 * 1024))
: > "$GPUMEM_TEST_LOG"
out=$(gpumem max 2>&1)
eq "$?" "1" "reserve larger than RAM"
contains "$out" "reserve of 10 GiB exceeds total memory" "max refuses an impossible reserve"
if [[ -s "$GPUMEM_TEST_LOG" ]]; then
    bad "impossible max wrote the sysctl"
else
    ok
fi
out=$(gpumem reset 2>&1)
eq "$?" "0" "reset still works when the reserve exceeds RAM"
contains "$(cat "$GPUMEM_TEST_LOG")" "iogpu.wired_limit_mb=0" "reset writes 0 anyway"
GPUMEM_TEST_MEMSIZE=$((96 * 1024 * 1024 * 1024))

out=$(bash "$SHELL_UTILS_ROOT/lib/gpumem.sh" 2>&1)
eq "$?" "0" "executing gpumem.sh from bash prints help"
contains "$out" "usage: gpumem" "bash exec help"

out=$(zsh "$SHELL_UTILS_ROOT/lib/gpumem.sh" 2>&1)
eq "$?" "0" "executing gpumem.sh from zsh prints help"
contains "$out" "usage: gpumem" "zsh exec help"

finish
