# mkvenv — create a Python virtual environment and activate it.

mkvenv() {
    local python="python3"
    local venvdir=".venv"
    local force=0
    local upgrade=1
    local python_set=0
    local dir_set=0
    local parent base parent_resolved full existed version

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                cat <<'EOF'
usage: mkvenv [options] [python] [directory]

Create a Python virtual environment and activate it in the current shell.
Source shell-utils first; running this file as a script only prints help.

Options:
  -p, --python EXE   Python executable (default: python3)
  -d, --dir DIR      Environment directory (default: .venv)
  -f, --force        Replace an existing environment
      --no-upgrade   Do not upgrade pip, setuptools, and wheel
  -h, --help         Show this help

Positional arguments match the flags, in order. A third positional
argument of "force" is the same as --force:

  mkvenv
  mkvenv python3.12
  mkvenv python3.12 .venv force
  mkvenv --python python3.12 --dir .venv --force
EOF
                return 0
                ;;
            -f|--force)
                force=1
                shift
                ;;
            --no-upgrade)
                upgrade=0
                shift
                ;;
            -p|--python)
                if [[ $# -lt 2 ]]; then
                    printf 'mkvenv: option requires a value: %s\n' "$1" >&2
                    return 2
                fi
                python="$2"
                python_set=1
                shift 2
                ;;
            -d|--dir)
                if [[ $# -lt 2 ]]; then
                    printf 'mkvenv: option requires a value: %s\n' "$1" >&2
                    return 2
                fi
                venvdir="$2"
                dir_set=1
                shift 2
                ;;
            --)
                shift
                break
                ;;
            -*)
                printf 'mkvenv: unknown option: %s\n' "$1" >&2
                return 2
                ;;
            *)
                if [[ "$python_set" -eq 0 ]]; then
                    python="$1"
                    python_set=1
                elif [[ "$dir_set" -eq 0 ]]; then
                    venvdir="$1"
                    dir_set=1
                elif [[ "$1" == "force" && "$force" -eq 0 ]]; then
                    force=1
                else
                    printf 'mkvenv: unexpected argument: %s\n' "$1" >&2
                    return 2
                fi
                shift
                ;;
        esac
    done

    while [[ $# -gt 0 ]]; do
        if [[ "$python_set" -eq 0 ]]; then
            python="$1"
            python_set=1
        elif [[ "$dir_set" -eq 0 ]]; then
            venvdir="$1"
            dir_set=1
        elif [[ "$1" == "force" && "$force" -eq 0 ]]; then
            force=1
        else
            printf 'mkvenv: unexpected argument: %s\n' "$1" >&2
            return 2
        fi
        shift
    done

    case "$venvdir" in
        ""|.|..|/)
            printf 'mkvenv: refusing directory: %s\n' "$venvdir" >&2
            return 2
            ;;
        -*)
            printf 'mkvenv: directory must not start with "-": %s\n' "$venvdir" >&2
            return 2
            ;;
    esac

    if [[ "$python" == */* ]]; then
        if [[ ! -x "$python" ]]; then
            printf 'mkvenv: Python is not executable: %s\n' "$python" >&2
            return 1
        fi
    elif ! command -v "$python" >/dev/null 2>&1; then
        printf 'mkvenv: Python not found: %s\n' "$python" >&2
        return 1
    fi

    if [[ -L "$venvdir" ]]; then
        printf 'mkvenv: refusing to replace a symlink: %s\n' "$venvdir" >&2
        return 1
    fi
    if [[ -e "$venvdir" && ! -d "$venvdir" ]]; then
        printf 'mkvenv: path exists and is not a directory: %s\n' "$venvdir" >&2
        return 1
    fi

    parent=$(dirname -- "$venvdir") || return 1
    base=$(basename -- "$venvdir") || return 1
    if [[ ! -d "$parent" ]]; then
        printf 'mkvenv: parent directory does not exist: %s\n' "$parent" >&2
        return 1
    fi
    parent_resolved=$(cd -- "$parent" && pwd -P) || return 1
    full="${parent_resolved}/${base}"
    if [[ "$full" == "/" || ( -n ${HOME:-} && "$full" == "$HOME" ) ]]; then
        printf 'mkvenv: refusing directory: %s\n' "$venvdir" >&2
        return 2
    fi

    if [[ -d "$venvdir" ]]; then
        if [[ "$force" -eq 0 ]]; then
            printf 'Virtual environment %s already exists.\n' "$venvdir" >&2
            printf 'Recreate it with: mkvenv --force --dir %s\n' "$venvdir" >&2
            return 1
        fi
        if [[ ! -f "$venvdir/pyvenv.cfg" ]]; then
            printf 'mkvenv: refusing to remove %s (not a virtual environment)\n' "$venvdir" >&2
            return 1
        fi
        command rm -rf -- "$venvdir" || return 1
    fi

    existed=0
    if [[ -d "$venvdir" ]]; then
        existed=1
    fi
    if ! "$python" -m venv "$venvdir"; then
        if [[ "$existed" -eq 0 && -d "$venvdir" ]]; then
            command rm -rf -- "$venvdir"
        fi
        printf 'mkvenv: failed to create %s with %s\n' "$venvdir" "$python" >&2
        return 1
    fi
    if [[ ! -f "$venvdir/bin/activate" ]]; then
        printf 'mkvenv: %s has no bin/activate script\n' "$venvdir" >&2
        return 1
    fi

    # shellcheck disable=SC1091
    . "$venvdir/bin/activate" || return 1

    if [[ "$upgrade" -eq 1 ]]; then
        if ! "$venvdir/bin/python" -m pip install --upgrade pip setuptools wheel; then
            printf 'mkvenv: environment created, but package upgrade failed\n' >&2
            return 1
        fi
    fi

    version=$("$venvdir/bin/python" -c 'import sys; print("%d.%d.%d" % sys.version_info[:3])') || version="unknown"
    printf 'Activated %s (Python %s)\n' "$venvdir" "$version"
}

_mkvenv_is_sourced() {
    if [[ -n ${ZSH_VERSION:-} ]]; then
        case ${ZSH_EVAL_CONTEXT:-} in
            *:file*) return 0 ;;
            *) return 1 ;;
        esac
    fi
    [[ ${BASH_SOURCE[0]} != "$0" ]]
}

if ! _mkvenv_is_sourced; then
    mkvenv --help
    exit $?
fi
unset -f _mkvenv_is_sourced
