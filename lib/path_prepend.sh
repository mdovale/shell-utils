# path_prepend — prepend existing directories to PATH, skipping duplicates.

path_prepend() {
    local dir chosen=""

    if [[ $# -eq 0 || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
        if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
            cat <<'EOF'
usage: path_prepend <directory>...

Prepend directories to PATH. The first argument ends up first.
Missing directories are ignored, so this is safe in shell startup.
Directories already on PATH are left where they are.
A directory that contains ":" is skipped.

  path_prepend "$HOME/.local/bin" /opt/homebrew/bin
  path_prepend "/Applications/Cursor.app/Contents/Resources/app/bin"
EOF
            return 0
        fi
        printf 'usage: path_prepend <directory>...\n' >&2
        return 2
    fi

    for dir in "$@"; do
        if [[ "$dir" != "/" ]]; then
            dir="${dir%/}"
        fi
        if [[ -z "$dir" ]]; then
            continue
        fi
        case "$dir" in
            *:*)
                printf 'path_prepend: skipping path that contains colon: %s\n' "$dir" >&2
                continue
                ;;
        esac
        if [[ ! -d "$dir" ]]; then
            continue
        fi
        case ":${PATH:-}:$chosen:" in
            *":$dir:"*) continue ;;
        esac
        if [[ -z "$chosen" ]]; then
            chosen="$dir"
        else
            chosen="${chosen}:$dir"
        fi
    done

    if [[ -n "$chosen" ]]; then
        if [[ -z ${PATH:-} ]]; then
            PATH="$chosen"
        else
            PATH="${chosen}:${PATH}"
        fi
    fi
    export PATH
    hash -r 2>/dev/null || true
}

_path_prepend_is_sourced() {
    if [[ -n ${ZSH_VERSION:-} ]]; then
        case ${ZSH_EVAL_CONTEXT:-} in
            *:file*) return 0 ;;
            *) return 1 ;;
        esac
    fi
    [[ ${BASH_SOURCE[0]} != "$0" ]]
}

if ! _path_prepend_is_sourced; then
    path_prepend --help
    exit $?
fi
unset -f _path_prepend_is_sourced
