. "$(cd "$(dirname "$0")" && pwd)/harness.sh"

if [[ -n ${BASH_VERSION:-} ]]; then
    shopt -s expand_aliases
fi
alias gitsize='printf aliased\n'
alias grep='printf aliased-grep\n'

# shellcheck disable=SC1091
. "$SHELL_UTILS_ROOT/init.sh"

is_function gitsize
is_function path_prepend

if alias gitsize >/dev/null 2>&1; then
    bad "gitsize alias still shadows the function"
else
    ok
fi

out=$(gitsize --help)
eq "$?" "0" "gitsize function runs"
contains "$out" "usage: gitsize" "gitsize help after removing the alias"

if alias grep >/dev/null 2>&1; then
    ok
else
    bad "unrelated aliases were removed"
fi

if [[ -n ${BASH_VERSION:-} ]]; then
    if shopt -q expand_aliases; then
        ok
    else
        bad "expand_aliases was left disabled"
    fi
fi

finish
