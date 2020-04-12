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
mkfs.ext4 -L "rootfs" "${device}2"
mount "${device}2" /mnt

if [ -n "${MIRROR}" ]; then
  echo "Server = ${MIRROR}" >/etc/pacman.d/mirrorlist
else
  pacman -Sy --noconfirm reflector
  reflector --age 12 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
fi
pacstrap -M /mnt base linux grub openssh sudo polkit haveged netctl python reflector
swapon "${device}1"
genfstab -p /mnt >>/mnt/etc/fstab
swapoff "${device}1"

arch-chroot /mnt /usr/bin/sed -i 's/^#Server/Server/' /etc/pacman.d/mirrorlist
arch-chroot /mnt /bin/bash
