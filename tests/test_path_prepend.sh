. "$(cd "$(dirname "$0")" && pwd)/harness.sh"
# shellcheck disable=SC1091
. "$SHELL_UTILS_ROOT/init.sh"

tmp=$(mktemp -d) || exit 1
cleanup() {
    cd "$SHELL_UTILS_ROOT" || cd / || true
    rm -rf "$tmp"
}
trap cleanup EXIT

saved_path=$PATH
mkdir -p "$tmp/a" "$tmp/b" "$tmp/has:colon"
echo x > "$tmp/file"

out=$(path_prepend --help)
eq "$?" "0" "path_prepend --help status"
contains "$out" "usage: path_prepend" "path_prepend help"
status_is 2 path_prepend

PATH=/usr/bin
path_prepend "$tmp/a" "$tmp/b"
eq "$PATH" "$tmp/a:$tmp/b:/usr/bin" "first argument stays first on PATH"

PATH="$tmp/b:/usr/bin"
path_prepend "$tmp/b" "$tmp/a"
eq "$PATH" "$tmp/a:$tmp/b:/usr/bin" "existing entries stay put"

PATH=/usr/bin
path_prepend "$tmp/missing" "$tmp/file" "$tmp/a"
eq "$PATH" "$tmp/a:/usr/bin" "missing paths and files are skipped"

PATH=/usr/bin
path_prepend "$tmp/has:colon" "$tmp/b" 2>"$tmp/err"
contains "$(/bin/cat "$tmp/err")" "colon" "colon in a path is reported"
eq "$PATH" "$tmp/b:/usr/bin" "colon path was not added"

PATH=$saved_path
finish
