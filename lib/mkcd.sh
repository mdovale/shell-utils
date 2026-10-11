# mkcd — create a directory and cd into it.

mkcd() {
    local dir

    case "${1:-}" in
        -h|--help)
            cat <<'EOF'
usage: mkcd <directory>

Create a directory, including parents, and cd into it.
Relative paths ignore CDPATH.

  mkcd scratch/notes
EOF
            return 0
            ;;
        "")
            printf 'usage: mkcd <directory>\n' >&2
            return 2
            ;;
        --)
            shift
            ;;
        -*)
            printf 'mkcd: unknown option: %s\n' "$1" >&2
            return 2
            ;;
    esac

    if [[ $# -ne 1 ]]; then
        printf 'usage: mkcd <directory>\n' >&2
        return 2
    fi
    dir="$1"
    if [[ -z "$dir" ]]; then
        printf 'usage: mkcd <directory>\n' >&2
        return 2
    fi

    command mkdir -p -- "$dir" || return 1
    # A leading ./ keeps CDPATH from redirecting relative paths.
    if [[ "$dir" == /* ]]; then
        builtin cd -- "$dir" || return 1
    else
        builtin cd -- "./$dir" || return 1
    fi
}

_mkcd_is_sourced() {
    if [[ -n ${ZSH_VERSION:-} ]]; then
        case ${ZSH_EVAL_CONTEXT:-} in
            *:file*) return 0 ;;
            *) return 1 ;;
        esac
    fi
    [[ ${BASH_SOURCE[0]} != "$0" ]]
}

if ! _mkcd_is_sourced; then
    mkcd --help
    exit $?
fi
unset -f _mkcd_is_sourced
