# gpumem — inspect or change the macOS GPU wired-memory limit.

gpumem() {
    local key="iogpu.wired_limit_mb"
    local reserve_gb=${GPUMEM_RESERVE_GB:-10}
    local mode="status"
    local gb_canon=""
    local total_bytes=""
    local total_mb=0
    local current_mb=0
    local target_mb=0
    local max_mb=0
    local total_gib=""
    local limit_gib=""

    case "$reserve_gb" in
        ""|*[!0-9]*)
            printf 'gpumem: GPUMEM_RESERVE_GB must be a non-negative integer\n' >&2
            return 2
            ;;
    esac
    while [[ $reserve_gb == 0?* ]]; do
        reserve_gb=${reserve_gb#0}
    done
    if [[ -z $reserve_gb ]]; then
        reserve_gb=0
    fi

    if [[ $# -gt 0 && "$1" == "--" ]]; then
        shift
    fi
    if [[ $# -gt 1 ]]; then
        printf 'usage: gpumem [status | <GiB> | max | reset]\n' >&2
        return 2
    fi

    case "${1:-status}" in
        -h|--help|help)
            cat <<'EOF'
usage: gpumem [status | <GiB> | max | reset]

Show or change the macOS GPU wired-memory limit on Apple Silicon
(macOS 14 or later). The sysctl is iogpu.wired_limit_mb.

The value is a ceiling, not an allocation. It does not survive a reboot.
Changing it runs sysctl through sudo. With no argument, gpumem only reads.

  status, -s, --status   Show total memory and the current limit (default)
  <GiB>                  Set the limit to this many GiB
  max                    Set the limit to total RAM minus a reserve
  reset                  Restore the macOS default (about 75% of RAM)

  GPUMEM_RESERVE_GB      GiB left for macOS by max, and the minimum an
                         explicit size must leave free (default: 10)

  gpumem
  gpumem 86
  gpumem max
  GPUMEM_RESERVE_GB=12 gpumem max
  gpumem reset
EOF
            return 0
            ;;
        status|-s|--status)
            mode="status"
            ;;
        reset)
            mode="set"
            target_mb=0
            ;;
        max)
            mode="max"
            ;;
        -*)
            printf 'gpumem: unknown option: %s\n' "$1" >&2
            return 2
            ;;
        *[!0-9]*)
            printf 'gpumem: invalid argument: %s (try: gpumem --help)\n' "$1" >&2
            return 2
            ;;
        *)
            mode="set"
            gb_canon=$1
            while [[ $gb_canon == 0?* ]]; do
                gb_canon=${gb_canon#0}
            done
            if [[ -z $gb_canon ]]; then
                gb_canon=0
            fi
            ;;
    esac

    if ! current_mb=$(command sysctl -n "$key" 2>/dev/null); then
        printf "gpumem: '%s' is unavailable (requires Apple Silicon and macOS 14+)\n" "$key" >&2
        return 1
    fi
    case "$current_mb" in
        ""|*[!0-9]*)
            printf "gpumem: unexpected %s: %s\n" "$key" "$current_mb" >&2
            return 1
            ;;
    esac

    if ! total_bytes=$(command sysctl -n hw.memsize 2>/dev/null); then
        printf 'gpumem: cannot read hw.memsize\n' >&2
        return 1
    fi
    case "$total_bytes" in
        ""|*[!0-9]*)
            printf 'gpumem: unexpected hw.memsize: %s\n' "$total_bytes" >&2
            return 1
            ;;
    esac
    total_mb=$((total_bytes / 1024 / 1024))
    max_mb=$((total_mb - 10#$reserve_gb * 1024))

    if [[ "$mode" == "max" ]]; then
        if ((max_mb < 0)); then
            printf 'gpumem: reserve of %s GiB exceeds total memory\n' "$reserve_gb" >&2
            return 1
        fi
        target_mb=$max_mb
        mode="set"
    elif [[ "$mode" == "set" && "$gb_canon" != "" && "$gb_canon" != "0" ]]; then
        if ((max_mb < 0)); then
            printf 'gpumem: reserve of %s GiB exceeds total memory\n' "$reserve_gb" >&2
            return 1
        fi
        # Compare in GiB first so a huge argument cannot overflow the multiply.
        if ((${#gb_canon} > 9)) || ((10#$gb_canon > max_mb / 1024)); then
            printf 'gpumem: refusing %s GiB; that leaves under %s GiB for macOS (max allowed: %d GiB)\n' \
                "$gb_canon" "$reserve_gb" "$((max_mb / 1024))" >&2
            return 1
        fi
        target_mb=$((10#$gb_canon * 1024))
    fi

    if [[ "$mode" == "set" ]]; then
        command sudo sysctl -w "$key=$target_mb" >/dev/null || return 1
        current_mb=$target_mb
    fi

    total_gib=$(command awk -v mb="$total_mb" 'BEGIN { printf "%.1f", mb / 1024 }') || return 1
    printf 'Total memory : %s GiB\n' "$total_gib"
    if ((current_mb == 0)); then
        printf 'GPU limit    : macOS default (~75%% of total)\n'
    else
        limit_gib=$(command awk -v mb="$current_mb" 'BEGIN { printf "%.1f", mb / 1024 }') || return 1
        printf 'GPU limit    : %s GiB (%d MB)\n' "$limit_gib" "$current_mb"
    fi
}

_gpumem_is_sourced() {
    if [[ -n ${ZSH_VERSION:-} ]]; then
        case ${ZSH_EVAL_CONTEXT:-} in
            *:file*) return 0 ;;
            *) return 1 ;;
        esac
    fi
    [[ ${BASH_SOURCE[0]} != "$0" ]]
}

if ! _gpumem_is_sourced; then
    gpumem --help
    exit $?
fi
unset -f _gpumem_is_sourced
