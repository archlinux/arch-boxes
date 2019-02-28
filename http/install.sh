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
mount "${device}2" /mnt

cp /etc/pacman.conf .
cat << __EOF__ >> pacman.conf
[options]
NoExtract  = usr/share/help/* !usr/share/help/en*
NoExtract  = usr/share/gtk-doc/html/* usr/share/doc/*
NoExtract  = usr/share/locale/* usr/share/X11/locale/* usr/share/i18n/*
NoExtract   = !*locale*/en*/* !usr/share/i18n/charmaps/UTF-8.gz !usr/share/*locale*/locale.*
NoExtract   = !usr/share/*locales/en_?? !usr/share/*locales/i18n* !usr/share/*locales/iso*
NoExtract   = !usr/share/*locales/trans*
NoExtract  = usr/share/man/* usr/share/info/*
NoExtract  = usr/share/vim/vim*/lang/*
__EOF__

pacstrap -C ./pacman.conf /mnt base grub openssh sudo polkit btrfs-progs haveged
cp pacman.conf /mnt/etc/pacman.conf
swapon "${device}1"
genfstab -p /mnt >> /mnt/etc/fstab
swapoff "${device}1"

arch-chroot /mnt /bin/bash
