#!/bin/bash

set -e
set -x

# Make sure unwritten data has been flushed beforehand
sync
# Write zeros to improve virtual disk compaction.
zerofile=$(/usr/bin/mktemp /zerofile.XXXXX)
dd if=/dev/zero of="$zerofile" bs=1M || true
rm -f "$zerofile"
sync
