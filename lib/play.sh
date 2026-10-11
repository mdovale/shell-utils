# play — create a dated scratch directory and open it.

play() {
    local name=""
    local name_set=0
    local do_open=1
    local make_notebook=1
    local editor=""
    local root date_stamp folder_name folder_path notebook_path n

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                cat <<'EOF'
usage: play [name] [options]

Create a dated scratch directory, cd into it, and open it.
The folder name is YYYYMMDD_name. If that exists, the next one is
YYYYMMDD_name-2, then YYYYMMDD_name-3. The default name is "playground".
A Jupyter notebook with the same name is created in the folder.

  PLAY_DIR      Parent directory (default: ~/playground)
  PLAY_EDITOR  Editor command (default: cursor, then $VISUAL, then $EDITOR)

Options:
  -e, --editor CMD   Editor to launch
  -n, --no-open      Do not launch an editor
      --no-notebook  Do not create a notebook
  -h, --help         Show this help

  play
  play experiment
  PLAY_DIR="$HOME/Work-local/__playground" play notes
EOF
                return 0
                ;;
            -n|--no-open)
                do_open=0
                shift
                ;;
            --no-notebook)
                make_notebook=0
                shift
                ;;
            -e|--editor)
                if [[ $# -lt 2 || -z "$2" ]]; then
                    printf 'play: option requires a value: %s\n' "$1" >&2
                    return 2
                fi
                editor="$2"
                shift 2
                ;;
            --)
                shift
                if [[ $# -gt 1 ]]; then
                    printf 'play: unexpected argument: %s\n' "$2" >&2
                    return 2
                fi
                if [[ $# -eq 1 ]]; then
                    if [[ "$name_set" -eq 1 ]]; then
                        printf 'play: unexpected argument: %s\n' "$1" >&2
                        return 2
                    fi
                    name="$1"
                    name_set=1
                fi
                break
                ;;
            -*)
                printf 'play: unknown option: %s\n' "$1" >&2
                return 2
                ;;
            *)
                if [[ "$name_set" -eq 1 ]]; then
                    printf 'play: unexpected argument: %s\n' "$1" >&2
                    return 2
                fi
                name="$1"
                name_set=1
                shift
                ;;
        esac
    done

    if [[ "$name_set" -eq 0 ]]; then
        name="playground"
    fi
    case "$name" in
        ""|.|..|*/*)
            printf 'play: invalid name: %s\n' "$name" >&2
            return 2
            ;;
    esac

    if [[ -n ${PLAY_DIR:-} ]]; then
        root=$PLAY_DIR
    elif [[ -n ${HOME:-} ]]; then
        root="$HOME/playground"
    else
        printf 'play: HOME is not set; set PLAY_DIR\n' >&2
        return 1
    fi

    if [[ "$do_open" -eq 1 ]]; then
        if [[ -z "$editor" && -n ${PLAY_EDITOR:-} ]]; then
            editor=$PLAY_EDITOR
        fi
        if [[ -z "$editor" ]] && command -v cursor >/dev/null 2>&1; then
            editor=cursor
        fi
        if [[ -z "$editor" && -n ${VISUAL:-} ]]; then
            editor=$VISUAL
        fi
        if [[ -z "$editor" && -n ${EDITOR:-} ]]; then
            editor=$EDITOR
        fi
        if [[ -z "$editor" ]]; then
            printf 'play: no editor found; set PLAY_EDITOR or pass --no-open\n' >&2
            return 1
        fi
        if ! command -v "$editor" >/dev/null 2>&1; then
            printf 'play: editor not found: %s\n' "$editor" >&2
            return 1
        fi
    fi

    command mkdir -p -- "$root" || return 1
    if [[ ! -w "$root" ]]; then
        printf 'play: directory is not writable: %s\n' "$root" >&2
        return 1
    fi

    date_stamp=$(date +%Y%m%d) || return 1
    n=1
    folder_name="${date_stamp}_${name}"
    folder_path="${root}/${folder_name}"
    while ! command mkdir -- "$folder_path" 2>/dev/null; do
        n=$((n + 1))
        if [[ "$n" -gt 100 ]]; then
            printf 'play: could not create a unique directory in %s\n' "$root" >&2
            return 1
        fi
        folder_name="${date_stamp}_${name}-${n}"
        folder_path="${root}/${folder_name}"
    done

    if [[ "$make_notebook" -eq 1 ]]; then
        notebook_path="${folder_path}/${folder_name}.ipynb"
        if [[ ! -f "$notebook_path" ]]; then
            printf '%s\n' '{"cells":[],"metadata":{},"nbformat":4,"nbformat_minor":5}' > "$notebook_path" || return 1
        fi
    fi

    builtin cd -- "$folder_path" || return 1
    printf '%s\n' "$folder_path"

    if [[ "$do_open" -eq 1 ]]; then
        "$editor" "$folder_path" || return 1
    fi
}

_play_is_sourced() {
    if [[ -n ${ZSH_VERSION:-} ]]; then
        case ${ZSH_EVAL_CONTEXT:-} in
            *:file*) return 0 ;;
            *) return 1 ;;
        esac
    fi
    [[ ${BASH_SOURCE[0]} != "$0" ]]
}

if ! _play_is_sourced; then
    play --help
    exit $?
fi
unset -f _play_is_sourced
