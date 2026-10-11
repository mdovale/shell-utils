. "$(cd "$(dirname "$0")" && pwd)/harness.sh"
# shellcheck disable=SC1091
. "$SHELL_UTILS_ROOT/init.sh"

tmp=$(mktemp -d) || exit 1
cleanup() {
    cd "$SHELL_UTILS_ROOT" || cd / || true
    rm -rf "$tmp"
}
trap cleanup EXIT

out=$(extract --help)
eq "$?" "0" "extract --help status"
contains "$out" "usage: extract" "extract help"
status_is 2 extract

cd "$tmp"
echo hello > a.txt
tar -czf a.tar.gz a.txt
rm a.txt
extract a.tar.gz
eq "$?" "0" "extract tar.gz status"
eq "$(cat a.txt)" "hello" "tar.gz payload"
if [[ -f a.tar.gz ]]; then ok; else bad "tar.gz archive was removed"; fi

echo zip-body > z.txt
zip -q z.ZIP z.txt
rm z.txt
extract z.ZIP
eq "$?" "0" "extract uppercase zip status"
eq "$(cat z.txt)" "zip-body" "zip payload"

echo gzip-body > g.txt
gzip g.txt
extract g.txt.gz
eq "$?" "0" "extract gz status"
eq "$(cat g.txt)" "gzip-body" "gz payload"
if [[ -f g.txt.gz ]]; then ok; else bad "gz archive was removed"; fi

echo bz-body > b.txt
bzip2 -k b.txt
rm b.txt
extract b.txt.bz2
eq "$?" "0" "extract bz2 status"
eq "$(cat b.txt)" "bz-body" "bz2 payload"
if [[ -f b.txt.bz2 ]]; then ok; else bad "bz2 archive was removed"; fi

echo plain > plain
tar -cf plain.tar plain
rm plain
extract plain.tar
eq "$(cat plain)" "plain" "plain tar payload"

echo nope > nope.rar
extract nope.rar a.tar.gz
eq "$?" "1" "extract reports a bad archive and continues"
if [[ -f a.txt ]]; then ok; else bad "good archive was skipped after a failure"; fi

status_is 1 extract missing.tar.gz

finish
