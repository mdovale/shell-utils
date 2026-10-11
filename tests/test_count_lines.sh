. "$(cd "$(dirname "$0")" && pwd)/harness.sh"
# shellcheck disable=SC1091
. "$SHELL_UTILS_ROOT/init.sh"

tmp=$(mktemp -d) || exit 1
cleanup() {
    cd "$SHELL_UTILS_ROOT" || cd / || true
    rm -rf "$tmp"
}
trap cleanup EXIT

out=$(count_lines --help)
eq "$?" "0" "count_lines --help status"
contains "$out" "usage: count_lines" "count_lines help"
status_is 2 count_lines
status_is 1 count_lines "$tmp/missing" py

mkdir -p "$tmp/proj/sub" "$tmp/proj/node_modules" "$tmp/proj/.venv"
printf 'a\nb\n' > "$tmp/proj/a.py"
printf 'c\n' > "$tmp/proj/sub/b.py"
printf 'd\ne\nf\ng\n' > "$tmp/proj/my file.py"
printf 'skip\n' > "$tmp/proj/skip.txt"
printf 'n\nn\nn\nn\nn\nn\nn\nn\nn\n' > "$tmp/proj/node_modules/c.py"
printf 'v\n' > "$tmp/proj/.venv/d.py"

out=$(count_lines "$tmp/proj" "py, py")
eq "$?" "0" "count_lines status"
contains "$out" "a.py" "counts a.py"
contains "$out" "b.py" "counts nested py"
contains "$out" "my file.py" "counts names with spaces"
not_contains "$out" "node_modules" "skips node_modules"
not_contains "$out" ".venv" "skips .venv"
not_contains "$out" "skip.txt" "skips other extensions"
contains "$out" "total" "prints a total"

out=$(count_lines --all "$tmp/proj" py)
contains "$out" "node_modules" "--all includes node_modules"
contains "$out" ".venv/d.py" "--all includes .venv"

count_lines "$tmp/proj" py "$tmp/out.txt" >/dev/null
if [[ -s "$tmp/out.txt" ]]; then ok; else bad "output file was not written"; fi

out=$(count_lines "$tmp/proj" rs)
eq "$?" "0" "no matches is success"
contains "$out" "No matching files" "no-match message"

status_is 2 count_lines "$tmp/proj" 'py,*'
status_is 2 count_lines "$tmp/proj" ", , ."

finish
