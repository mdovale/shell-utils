. "$(cd "$(dirname "$0")" && pwd)/harness.sh"
# shellcheck disable=SC1091
. "$SHELL_UTILS_ROOT/init.sh"

tmp=$(mktemp -d) || exit 1
cleanup() {
    cd "$SHELL_UTILS_ROOT" || cd / || true
    rm -rf "$tmp"
}
trap cleanup EXIT

today=$(date +%Y%m%d)
mkdir -p "$tmp/root"

out=$(play --help)
eq "$?" "0" "play --help status"
contains "$out" "usage: play" "play help"
status_is 2 play --no-open "bad/name"
status_is 2 play --nope

PLAY_DIR="$tmp/root" play --no-open --no-notebook "my scratch"
eq "$?" "0" "play status"
eq "$PWD" "$tmp/root/${today}_my scratch" "play cds into a dated folder"
if [[ -e "$PWD/${today}_my scratch.ipynb" ]]; then
    bad "notebook was created with --no-notebook"
else
    ok
fi

cd "$tmp"
PLAY_DIR="$tmp/root" play --no-open notes
eq "$PWD" "$tmp/root/${today}_notes" "play uses the given name"
if [[ -f "$PWD/${today}_notes.ipynb" ]]; then ok; else bad "notebook was not created"; fi
contains "$(cat "$PWD/${today}_notes.ipynb")" "nbformat" "notebook is a jupyter document"

cd "$tmp"
PLAY_DIR="$tmp/root" play --no-open notes
eq "$PWD" "$tmp/root/${today}_notes-2" "second folder gets a numeric suffix"

cd "$tmp"
PLAY_DIR="$tmp/root" play --no-open
eq "$PWD" "$tmp/root/${today}_playground" "default name is playground"

cat > "$tmp/editor" << 'EOF'
#!/bin/sh
printf '%s\n' "$PWD" "$@" > "$PLAY_LOG"
EOF
chmod +x "$tmp/editor"
export PLAY_LOG="$tmp/log"
cd "$tmp"
PLAY_DIR="$tmp/root" PLAY_EDITOR="$tmp/editor" play --no-notebook demo
eq "$?" "0" "play editor status"
eq "$PWD" "$tmp/root/${today}_demo" "play cds before opening the editor"
contains "$(cat "$PLAY_LOG")" "$tmp/root/${today}_demo" "editor receives the folder"

finish
