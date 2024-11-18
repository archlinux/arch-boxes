#!/bin/bash
# shellcheck disable=SC2034,SC2154
IMAGE_NAME="Arch-Linux-x86_64-libvirt-executor-${build_version}.qcow2"
DISK_SIZE="40G"
PACKAGES=(git git-lfs gitlab-runner)
SERVICES=()

function pre() {
  arch-chroot "${MOUNT}" /usr/bin/systemctl disable systemd-time-wait-sync
  sed -E 's/^#(IgnorePkg *=)/\1 linux/' -i "${MOUNT}/etc/pacman.conf"
  sed 's/^\(GRUB_CMDLINE_LINUX=".*\)"$/\1 lockdown=confidentiality"/' -i "${MOUNT}/etc/default/grub"
  arch-chroot "${MOUNT}" /usr/bin/grub-mkconfig -o /boot/grub/grub.cfg
  # We want to use the transient hostname
  # https://github.com/systemd/systemd/pull/30814
  rm -f "${MOUNT}/etc/hostname"

  cat <<EOF >"${MOUNT}/etc/systemd/network/80-dhcp.network"
[Match]
Name=en*
Name=eth*

[Network]
DHCP=yes
EOF
}

function post() {
  qemu-img convert -c -f raw -O qcow2 "${1}" "${2}"
  rm "${1}"
}
