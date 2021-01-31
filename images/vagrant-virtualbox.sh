#!/bin/bash
# shellcheck disable=SC2034,SC2154
IMAGE_NAME="Arch-Linux-x86_64-virtualbox-${build_version}.box"
# https://gitlab.archlinux.org/archlinux/arch-boxes/-/issues/116
DISK_SIZE="20G"
PACKAGES=(virtualbox-guest-utils-nox)
SERVICES=(vboxservice)

function pre() {
  vagrant_common
}

function post() {
  # Create vagrant box
  # VirtualBox-6.1.12 src/VBox/NetworkServices/Dhcpd/Config.cpp line 276
  local mac_address
  mac_address="080027$(openssl rand -hex 3 | tr '[:lower:]' '[:upper:]')"
  cat <<EOF >Vagrantfile
Vagrant.configure("2") do |config|
  config.vm.base_mac = "${mac_address}"
end
EOF
  echo '{"provider":"virtualbox"}' >metadata.json
  qemu-img convert -f raw -O vmdk "${1}" "packer-virtualbox.vmdk"
  rm "${1}"

  cp "${ORIG_PWD}/box.ovf" .
  sed -e "s/MACHINE_UUID/$(uuidgen)/" \
    -e "s/DISK_UUID/$(uuidgen)/" \
    -e "s/DISK_CAPACITY/$(qemu-img info --output=json "packer-virtualbox.vmdk" | jq '."virtual-size"')/" \
    -e "s/UNIX/$(date +%s)/" \
    -e "s/MAC_ADDRESS/${mac_address}/" \
    -i box.ovf

  tar -czf "${2}" Vagrantfile metadata.json packer-virtualbox.vmdk box.ovf
  rm Vagrantfile metadata.json packer-virtualbox.vmdk box.ovf
}
