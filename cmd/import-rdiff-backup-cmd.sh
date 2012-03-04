#!/bin/sh

set -e

usage() {
    echo "Usage: bup import-rdiff-backup [-n]" \
        "<path to rdiff-backup root> <backup name>"
    echo "-n,--dry-run: just print what would be done"
    exit -1
}

control_c() {
    echo "bup import-rdiff-backup: signal 2 received" 1>&2
    exit $?
}

trap control_c SIGINT

DRY_RUN=
while [ "$1" = "-n" -o "$1" = "--dry-run" ]; do
    DRY_RUN=echo
    shift
done

bup()
{
    $DRY_RUN "${BUP_MAIN_EXE:=bup}" "$@"
}

SNAPSHOT_ROOT=$1
BRANCH=$2

[ -n "$SNAPSHOT_ROOT" -a "$#" = 2 ] || usage

if [ ! -e "$SNAPSHOT_ROOT/." ]; then
    echo "'$SNAPSHOT_ROOT' isn't a directory!"
    exit 1
fi


backups=$(rdiff-backup --list-increments --parsable-output "$SNAPSHOT_ROOT")
backups_count=$(echo "$backups" | wc -l)
counter=1
echo "$backups" |
while read timestamp type; do
    TMPDIR=$(mktemp -d)

    echo "Importing backup from $(date --date=@$timestamp +%c) ($counter / $backups_count)" 1>&2
    echo 1>&2

    echo "Restoring from rdiff-backup..." 1>&2
    rdiff-backup -r $timestamp "$SNAPSHOT_ROOT" "$TMPDIR"
    echo 1>&2

    echo "Importing into bup..." 1>&2
    TMPIDX=$(mktemp -u)
    bup index -ux -f "$TMPIDX" "$TMPDIR"
    bup save --strip --date="$TIMESTAMP" -f "$TMPIDX" -n "$BRANCH" "$TMPDIR"
    rm -f "$TMPIDX"

    rm -rf "$TMPDIR"
    counter=$((counter+1))
    echo 1>&2
    echo 1>&2
done
