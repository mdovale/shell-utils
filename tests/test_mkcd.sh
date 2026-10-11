. "$(cd "$(dirname "$0")" && pwd)/harness.sh"
# shellcheck disable=SC1091
. "$SHELL_UTILS_ROOT/init.sh"

tmp=$(mktemp -d) || exit 1
cleanup() {
    cd "$SHELL_UTILS_ROOT" || cd / || true
    rm -rf "$tmp"
}
trap cleanup EXIT

out=$(mkcd --help)
eq "$?" "0" "mkcd --help status"
contains "$out" "usage: mkcd" "mkcd help"

status_is 2 mkcd
status_is 2 mkcd -p
if [[ -d "$SHELL_UTILS_ROOT/-p" ]]; then
    bad "mkcd -p created a directory"
else
    ok
fi

mkdir -p "$tmp/decoy/target" "$tmp/work"
cd "$tmp/work"
CDPATH="$tmp/decoy"
mkcd target
eq "$?" "0" "mkcd status"
eq "$PWD" "$tmp/work/target" "mkcd ignores CDPATH"
unset CDPATH

cd "$tmp"
mkcd a/b/c
eq "$PWD" "$tmp/a/b/c" "mkcd creates parents"

cd "$tmp"
mkcd -- -odd
eq "$PWD" "$tmp/-odd" "mkcd accepts a leading-dash name after --"

finish
