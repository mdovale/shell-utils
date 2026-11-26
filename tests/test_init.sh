. "$(cd "$(dirname "$0")" && pwd)/harness.sh"
# shellcheck disable=SC1091
. "$SHELL_UTILS_ROOT/init.sh"

for name in mkvenv play docku count_lines mkcd extract path_prepend gitsize gpumem; do
    is_function "$name"
done

if [[ -n ${_shell_utils_root:-} || -n ${_shell_utils_file:-} || -n ${_shell_utils_status:-} ]]; then
    bad "loader variables leaked"
else
    ok
fi

if [[ -n ${ZSH_VERSION:-} ]]; then
    if whence -w _shell_utils_load >/dev/null 2>&1; then
        bad "loader function leaked"
    else
        ok
    fi
elif [[ $(type -t _shell_utils_load 2>/dev/null) == "function" ]]; then
    bad "loader function leaked"
else
    ok
fi

# shellcheck disable=SC1091
. "$SHELL_UTILS_ROOT/init.sh"
is_function mkcd

out=$(bash "$SHELL_UTILS_ROOT/init.sh" 2>&1)
eq "$?" "1" "executing init.sh from bash should fail"
contains "$out" "source this file" "bash exec message"

out=$(zsh "$SHELL_UTILS_ROOT/init.sh" 2>&1)
eq "$?" "1" "executing init.sh from zsh should fail"
contains "$out" "source this file" "zsh exec message"

out=$(bash "$SHELL_UTILS_ROOT/lib/mkcd.sh" 2>&1)
eq "$?" "0" "executing a function file prints help"
contains "$out" "usage: mkcd" "mkcd help from bash"

out=$(zsh "$SHELL_UTILS_ROOT/lib/play.sh" 2>&1)
eq "$?" "0" "executing play.sh prints help"
contains "$out" "usage: play" "play help from zsh"

finish
