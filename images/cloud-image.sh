#!/bin/bash
# shellcheck disable=SC2034,SC2154
IMAGE_NAME="Arch-Linux-x86_64-cloudimg-${build_version}.qcow2"
DISK_SIZE=""
# The growpart module[1] requires the growpart program, provided by the
# cloud-guest-utils package
# [1] https://cloudinit.readthedocs.io/en/latest/topics/modules.html#growpart
PACKAGES=(cloud-init cloud-guest-utils)
SERVICES=(cloud-init-local.service cloud-init.service cloud-config.service cloud-final.service)

function pre() {
  true
}

function post() {
  qemu-img convert -c -f raw -O qcow2 "${1}" "${2}"
  rm "${1}"
}
