#!/bin/bash

set -e
set -x

sync
btrfs filesystem defrag -r -czstd /
sync
exit 0
# Make sure unwritten data has been flushed beforehand
sync
# Write zeros to improve virtual disk compaction.
zerofile=$(/usr/bin/mktemp /zerofile.XXXXX)
dd if=/dev/zero of="$zerofile" bs=1M || true
rm -f "$zerofile"
sync
