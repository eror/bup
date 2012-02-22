#!/bin/sh

set -e

usage() {
    echo "Usage: bup import-duplicity [-n]" \
        "<duplicity target url> <backup name>"
    echo "-n,--dry-run: just print what would be done"
    exit -1
}

DRY_RUN=
while [ "$1" = "-n" -o "$1" = "--dry-run" ]; do
    DRY_RUN=echo
    shift
done

bup()
{
    $DRY_RUN "${BUP_MAIN_EXE:=bup}" "$@"
}

DUPLICITY_TARGET_URL=$1
BRANCH=$2

[ -n "$DUPLICITY_TARGET_URL" -a "$#" = 2 ] || usage

duplicity collection-status --log-fd=3 "$DUPLICITY_TARGET_URL" 3>&1 1>/dev/null 2>/dev/null |
grep "[[:digit:]][[:digit:]]T" |
cut -d" " -f 3 |
while read dup_timestamp; do
  timestamp=$(python -c "import time,calendar; print str(int(calendar.timegm(time.strptime('$dup_timestamp', '%Y%m%dT%H%M%SZ'))))")
  TMPDIR=$(mktemp -d)

  duplicity restore -t "$dup_timestamp" "$DUPLICITY_TARGET_URL" "$TMPDIR"

  TMPIDX=$(mktemp -u)
  bup index -ux -f "$TMPIDX" "$TMPDIR"
  bup save --strip --date="$timestamp" -f "$TMPIDX" -n "$BRANCH" "$TMPDIR"
  rm -f "$TMPIDX"

  rm -rf "$TMPDIR"
done
