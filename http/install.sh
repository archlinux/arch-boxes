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

memory_size_in_mebibytes=$(free -m | awk '/^Mem:/ { print $2 }')
swap_size_in_mebibytes=$((memory_size_in_mebibytes * 2))

sgdisk -g --clear -n 1:0:+10M $device -c 1:boot -t 1:ef02
sgdisk -n 2:0:+${swap_size_in_mebibytes}M $device -c 2:swap -t 2:8200
sgdisk -n 3:0:0 $device -c 3:root
partprobe

mkswap /dev/disk/by-partlabel/swap
mkfs.btrfs /dev/disk/by-partlabel/root
mount -o compress-force=zstd PARTLABEL=root /mnt

echo "Server = ${MIRROR}" >/etc/pacman.d/mirrorlist
pacstrap /mnt base linux grub openssh sudo polkit haveged netctl python btrfs-progs reflector

arch-chroot /mnt /bin/bash
