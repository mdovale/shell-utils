# extract — unpack a common archive in the current directory.

extract() {
    local end_opts=0
    local nfiles=0
    local rc=0
    local file lower operand
    local -a files

    files=()
    while [[ $# -gt 0 ]]; do
        if [[ "$end_opts" -eq 0 ]]; then
            case "$1" in
                -h|--help)
                    cat <<'EOF'
usage: extract <archive>...

Unpack archives in the current directory. The archive file is kept.
Supported suffixes, in either case:

  .tar.gz .tgz .tar.bz2 .tbz2 .tar.xz .txz .tar
  .zip .gz .bz2 .xz

  extract release.tar.gz
  mkcd build && extract ../sources.zip
EOF
                    return 0
                    ;;
                --)
                    end_opts=1
                    shift
                    continue
                    ;;
                -*)
                    printf 'extract: unknown option: %s\n' "$1" >&2
                    return 2
                    ;;
            esac
        fi
        files+=("$1")
        nfiles=$((nfiles + 1))
        shift
    done

    if [[ "$nfiles" -eq 0 ]]; then
        printf 'usage: extract <archive>...\n' >&2
        return 2
    fi

    for file in "${files[@]}"; do
        if [[ ! -f "$file" ]]; then
            printf 'extract: not a file: %s\n' "$file" >&2
            rc=1
            continue
        fi
        lower=$(printf '%s' "$file" | command tr '[:upper:]' '[:lower:]')
        # bsdtar treats a leading "--" as a filename, so prefix dash-names instead.
        operand=$file
        case "$operand" in
            -*) operand="./$operand" ;;
        esac
        case "$lower" in
            *.tar.gz|*.tgz)
                command tar -xzf "$operand" || rc=1
                ;;
            *.tar.bz2|*.tbz2)
                command tar -xjf "$operand" || rc=1
                ;;
            *.tar.xz|*.txz)
                if ! command -v xz >/dev/null 2>&1 && ! command -v unxz >/dev/null 2>&1; then
                    printf 'extract: cannot unpack %s (missing xz)\n' "$file" >&2
                    rc=1
                    continue
                fi
                command tar -xJf "$operand" || rc=1
                ;;
            *.tar)
                command tar -xf "$operand" || rc=1
                ;;
            *.zip)
                if ! command -v unzip >/dev/null 2>&1; then
                    printf 'extract: cannot unpack %s (missing unzip)\n' "$file" >&2
                    rc=1
                    continue
                fi
                command unzip -oq -- "$operand" || rc=1
                ;;
            *.gz)
                command gunzip -k -f -- "$operand" || rc=1
                ;;
            *.bz2)
                command bunzip2 -k -f -- "$operand" || rc=1
                ;;
            *.xz)
                if ! command -v unxz >/dev/null 2>&1 && ! command -v xz >/dev/null 2>&1; then
                    printf 'extract: cannot unpack %s (missing xz)\n' "$file" >&2
                    rc=1
                    continue
                fi
                if command -v unxz >/dev/null 2>&1; then
                    command unxz -k -f -- "$operand" || rc=1
                else
                    command xz -d -k -f -- "$operand" || rc=1
                fi
                ;;
            *)
                printf 'extract: unsupported archive: %s\n' "$file" >&2
                rc=1
                ;;
        esac
    done
    return "$rc"
}

_extract_is_sourced() {
    if [[ -n ${ZSH_VERSION:-} ]]; then
        case ${ZSH_EVAL_CONTEXT:-} in
            *:file*) return 0 ;;
            *) return 1 ;;
        esac
    fi
    [[ ${BASH_SOURCE[0]} != "$0" ]]
}

if ! _extract_is_sourced; then
    extract --help
    exit $?
fi
unset -f _extract_is_sourced
