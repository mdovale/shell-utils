# gitsize — show how much space a Git repository occupies locally.

gitsize() {
    local repo="."

    case "${1:-}" in
        -h|--help)
            cat <<'EOF'
usage: gitsize [directory]

Show git count-objects for a repository. The default directory is ".".

  gitsize
  gitsize ~/src/project
EOF
            return 0
            ;;
        --)
            shift
            ;;
        -*)
            printf 'gitsize: unknown option: %s\n' "$1" >&2
            return 2
            ;;
    esac

    if [[ $# -gt 1 ]]; then
        printf 'usage: gitsize [directory]\n' >&2
        return 2
    fi
    if [[ $# -eq 1 ]]; then
        repo="$1"
    fi
    if [[ ! -d "$repo" ]]; then
        printf 'gitsize: not a directory: %s\n' "$repo" >&2
        return 1
    fi
    if ! command git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        printf 'gitsize: not a git repository: %s\n' "$repo" >&2
        return 1
    fi
    command git -C "$repo" count-objects -vH
}

_gitsize_is_sourced() {
    if [[ -n ${ZSH_VERSION:-} ]]; then
        case ${ZSH_EVAL_CONTEXT:-} in
            *:file*) return 0 ;;
            *) return 1 ;;
        esac
    fi
    [[ ${BASH_SOURCE[0]} != "$0" ]]
}

if ! _gitsize_is_sourced; then
    gitsize --help
    exit $?
fi
unset -f _gitsize_is_sourced
