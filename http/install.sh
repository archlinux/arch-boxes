#!/bin/bash

set -e
set -x

if [ -e /dev/vda ]; then
  device=/dev/vda
elif [ -e /dev/sda ]; then
  device=/dev/sda
else
  echo "ERROR: There is no disk available for installation" >&2
  exit 1
fi
export device

memory_size_in_kilobytes=$(free | awk '/^Mem:/ { print $2 }')
swap_size_in_kilobytes=$((memory_size_in_kilobytes * 2))
sfdisk "$device" <<EOF
label: dos
size=${swap_size_in_kilobytes}KiB, type=82
                                   type=83, bootable
EOF

mkswap "${device}1"
mkfs.btrfs -L "rootfs" "${device}2"
mount -o compress-force=zstd "${device}2" /mnt

echo "Server = ${MIRROR}" >/etc/pacman.d/mirrorlist
pacstrap -M /mnt base linux grub openssh sudo polkit haveged netctl python
echo "Server = ${MIRROR}" >/mnt/etc/pacman.d/mirrorlist

arch-chroot /mnt /bin/bash
