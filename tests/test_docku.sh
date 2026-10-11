. "$(cd "$(dirname "$0")" && pwd)/harness.sh"
# shellcheck disable=SC1091
. "$SHELL_UTILS_ROOT/init.sh"

tmp=$(mktemp -d) || exit 1
cleanup() {
    cd "$SHELL_UTILS_ROOT" || cd / || true
    rm -rf "$tmp"
}
trap cleanup EXIT

cat > "$tmp/docker" << 'EOF'
#!/bin/sh
printf '%s\n' "$@"
EOF
chmod +x "$tmp/docker"

out=$(docku --help)
eq "$?" "0" "docku --help status"
contains "$out" "usage: docku" "docku help"
status_is 2 docku --bogus
DOCKU_DOCKER="$tmp/missing-docker" status_is 1 docku echo hi

cd "$tmp"
out=$(DOCKU_DOCKER="$tmp/docker" docku --image alpine:3 echo hi)
eq "$?" "0" "fake docker status"
contains "$out" "--rm" "docku passes --rm"
contains "$out" "type=bind,source=${PWD},target=/work" "docku mounts the working directory"
contains "$out" "alpine:3" "docku uses the requested image"
contains "$out" $'\necho\nhi' "docku forwards the command"
case "$out" in
    *$'\n-i\n'*|*$'\n-it\n'*) ok ;;
    *) bad "docku did not pass -i or -it" ;;
esac

out=$(DOCKU_DOCKER="$tmp/docker" docku --user --image alpine:3 true)
contains "$out" $'\n-u\n'"$(id -u):$(id -g)" "docku --user passes uid:gid"

out=$(DOCKU_DOCKER="$tmp/docker" DOCKU_IMAGE="debian:12" docku)
contains "$out" "debian:12" "DOCKU_IMAGE overrides the image"
contains "$out" $'\nbash' "default command is bash"

finish
