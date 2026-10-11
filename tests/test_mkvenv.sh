. "$(cd "$(dirname "$0")" && pwd)/harness.sh"
# shellcheck disable=SC1091
. "$SHELL_UTILS_ROOT/init.sh"

tmp=$(mktemp -d) || exit 1
cleanup() {
    cd "$SHELL_UTILS_ROOT" || cd / || true
    rm -rf "$tmp"
}
trap cleanup EXIT

out=$(mkvenv --help)
eq "$?" "0" "mkvenv --help status"
contains "$out" "usage: mkvenv" "mkvenv help"
status_is 2 mkvenv --nope
status_is 2 mkvenv --no-upgrade --dir /
status_is 1 mkvenv --no-upgrade --python not-a-real-python-xyz --dir "$tmp/nope"
if [[ -d "$tmp/nope" ]]; then bad "mkvenv created a directory for a missing python"; else ok; fi

(
    cd "$tmp" || exit 97
    mkvenv --no-upgrade >/dev/null || exit 1
    [[ -n ${VIRTUAL_ENV:-} ]] || exit 2
    [[ -f .venv/pyvenv.cfg ]] || exit 3
    ./.venv/bin/python -c 'import sys; raise SystemExit(0 if sys.prefix.endswith(".venv") else 1)' || exit 4
)
eq "$?" "0" "mkvenv creates and activates .venv"

cd "$tmp"
status_is 1 mkvenv --no-upgrade
echo marker > "$tmp/.venv/marker"
mkvenv --no-upgrade --force >/dev/null
eq "$?" "0" "mkvenv --force status"
if [[ -f "$tmp/.venv/marker" ]]; then bad "--force kept the old environment"; else ok; fi
if [[ -f "$tmp/.venv/pyvenv.cfg" ]]; then ok; else bad "--force did not recreate the environment"; fi

mkdir -p "$tmp/notvenv"
echo keep > "$tmp/notvenv/keep"
status_is 1 mkvenv --no-upgrade --force --dir "$tmp/notvenv"
if [[ -f "$tmp/notvenv/keep" ]]; then ok; else bad "--force removed a directory that is not a venv"; fi

mkdir -p "$tmp/real"
ln -s "$tmp/real" "$tmp/link"
status_is 1 mkvenv --no-upgrade --force --dir "$tmp/link"
if [[ -d "$tmp/real" && -L "$tmp/link" ]]; then ok; else bad "mkvenv replaced a symlink"; fi

mkvenv --no-upgrade python3 "$tmp/env2" force >/dev/null
eq "$?" "0" "positional force status"
if [[ -f "$tmp/env2/pyvenv.cfg" ]]; then ok; else bad "positional arguments did not create the environment"; fi

if [[ -d "$SHELL_UTILS_ROOT/.venv" ]]; then bad "mkvenv wrote into the repo"; else ok; fi

finish
