#!/bin/bash
# shellcheck disable=SC2034,SC2154
IMAGE_NAME="Arch-Linux-x86_64-libvirt-${build_version}.box"
# https://gitlab.archlinux.org/archlinux/arch-boxes/-/issues/116
DISK_SIZE="20G"
PACKAGES=()
SERVICES=()

function pre() {
  vagrant_common
}

function post() {
  # Create vagrant box
  cat <<EOF >Vagrantfile
Vagrant.configure("2") do |config|
  config.vm.provider :libvirt do |libvirt|
    libvirt.driver = "kvm"
  end
end
EOF
  local virtual_size
  virtual_size="$(grep -o "^[0-9]*" <<<"${DISK_SIZE}")"
  echo '{"format":"qcow2","provider":"libvirt","virtual_size":'"${virtual_size}"'}' >metadata.json
  qemu-img convert -f raw -O qcow2 "${1}" box.img
  rm "${1}"

  tar -czf "${2}" Vagrantfile metadata.json box.img
  rm Vagrantfile metadata.json box.img
}
