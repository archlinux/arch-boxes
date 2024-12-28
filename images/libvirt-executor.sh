#!/bin/bash
# shellcheck disable=SC2034,SC2154
IMAGE_NAME="Arch-Linux-x86_64-libvirt-executor-${build_version}.qcow2"
DISK_SIZE="40G"
# https://docs.gitlab.com/runner/executors/custom.html#prerequisite-software-for-running-a-job
PACKAGES=(git git-lfs gitlab-runner)
SERVICES=()

function pre() {
  # The service is a bit slow and it is not needed for our use-case as
  # the "hardware" clock is always in UTC.
  # https://gitlab.archlinux.org/archlinux/arch-boxes/-/merge_requests/183
  arch-chroot "${MOUNT}" /usr/bin/systemctl disable systemd-time-wait-sync
  # Jobs often upgrade all the packages as the first thing, but we don't
  # want the linux package to be upgraded as that would mean that
  # relevant kernel modules cannot be loaded.
  # https://gitlab.archlinux.org/archlinux/packaging/packages/linux/-/issues/10
  sed -E 's/^#(IgnorePkg *=)/\1 linux/' -i "${MOUNT}/etc/pacman.conf"
  # https://gitlab.archlinux.org/archlinux/infrastructure/-/commit/ab612463a7ea119d4f0a34e9f2730b6c79cd7691
  sed 's/^\(GRUB_CMDLINE_LINUX=".*\)"$/\1 lockdown=confidentiality"/' -i "${MOUNT}/etc/default/grub"
  arch-chroot "${MOUNT}" /usr/bin/grub-mkconfig -o /boot/grub/grub.cfg
  # This is needed for our injected hostname to be used, which only
  # happens if a static hostname is not configured.
  # https://gitlab.archlinux.org/archlinux/infrastructure/-/commit/001300ff54d826696f2d7438063c09d2e8c9afd8
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
