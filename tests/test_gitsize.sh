. "$(cd "$(dirname "$0")" && pwd)/harness.sh"
# shellcheck disable=SC1091
. "$SHELL_UTILS_ROOT/init.sh"

tmp=$(mktemp -d) || exit 1
cleanup() {
    cd "$SHELL_UTILS_ROOT" || cd / || true
    rm -rf "$tmp"
}
trap cleanup EXIT

out=$(gitsize --help)
eq "$?" "0" "gitsize --help status"
contains "$out" "usage: gitsize" "gitsize help"

out=$(gitsize "$SHELL_UTILS_ROOT")
eq "$?" "0" "gitsize on this repo"
contains "$out" "size" "gitsize prints size"

out=$(gitsize "$tmp" 2>&1)
eq "$?" "1" "gitsize outside a repo"
contains "$out" "not a git repository" "gitsize repo error"

status_is 1 gitsize "$tmp/missing"
status_is 2 gitsize "$SHELL_UTILS_ROOT" extra
status_is 2 gitsize --not-an-option

finish
