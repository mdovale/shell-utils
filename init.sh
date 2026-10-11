# Source this file from bash or zsh. Do not execute it.
#   . /path/to/shell-utils/init.sh

if [[ -n ${ZSH_VERSION:-} ]]; then
    case ${ZSH_EVAL_CONTEXT:-} in
        *:file*) ;;
        *)
            printf 'shell-utils: source this file instead of executing it\n' >&2
            exit 1
            ;;
    esac
    _shell_utils_root=$(cd "$(dirname "${(%):-%x}")" && pwd -P) || return 1
elif [[ -n ${BASH_VERSION:-} ]]; then
    if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
        printf 'shell-utils: source this file instead of executing it\n' >&2
        exit 1
    fi
    _shell_utils_root=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P) || return 1
else
    printf 'shell-utils: source init.sh from bash or zsh\n' >&2
    return 1
fi

if [[ ! -d ${_shell_utils_root}/lib ]]; then
    printf 'shell-utils: missing lib directory: %s\n' "${_shell_utils_root}/lib" >&2
    unset _shell_utils_root
    return 1
fi

# Load inside a function so zsh options do not leak into the caller.
# Aliases are off while sourcing: zsh would otherwise expand an existing
# `gitsize` alias in `gitsize()` and abort the rest of the load.
_shell_utils_load() {
    local dir="$1"
    local file
    local name
    local loaded=0
    local rc=0
    local restore_expand_aliases=0

    if [[ -n ${ZSH_VERSION:-} ]]; then
        setopt local_options no_aliases nullglob
    elif shopt -q expand_aliases 2>/dev/null; then
        restore_expand_aliases=1
        shopt -u expand_aliases
    fi

    for name in count_lines docku extract gitsize mkcd mkvenv path_prepend play; do
        unalias "$name" 2>/dev/null || :
    done

    for file in "${dir}"/lib/*.sh; do
        if [[ ! -f ${file} ]]; then
            printf 'shell-utils: no function files in %s\n' "${dir}/lib" >&2
            rc=1
            break
        fi
        # shellcheck disable=SC1090
        if ! . "${file}"; then
            rc=$?
            break
        fi
        loaded=1
    done

    if [[ ${rc} -eq 0 && ${loaded} -eq 0 ]]; then
        printf 'shell-utils: no function files in %s\n' "${dir}/lib" >&2
        rc=1
    fi

    if [[ ${restore_expand_aliases} -eq 1 ]]; then
        shopt -s expand_aliases
    fi
    return "${rc}"
}

_shell_utils_load "${_shell_utils_root}"
_shell_utils_status=$?
unset _shell_utils_root
unset -f _shell_utils_load
# Expand the status first so the variable is gone after a failed load.
if [[ ${_shell_utils_status} -ne 0 ]]; then
    eval "unset _shell_utils_status; return ${_shell_utils_status}"
fi
unset _shell_utils_status
