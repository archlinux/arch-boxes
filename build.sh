#!/bin/bash
set -o nounset -o errexit
DISK_SIZE="2G"
IMAGE="image.img"
# shellcheck disable=SC2016
MIRROR='https://mirror.pkgbuild.com/$repo/os/$arch'

if [ "$(id -u)" -ne 0 ]; then
  echo "root is required"
  exit 1
fi

ORIG_PWD="${PWD}"
OUTPUT="${PWD}/output"
mkdir -p "tmp" "${OUTPUT}"
if [ -n "${SUDO_UID:-}" ]; then
  chown "${SUDO_UID}:${SUDO_GID}" "tmp" "${OUTPUT}"
fi
TMPDIR="$(mktemp --directory --tmpdir="${PWD}/tmp")"
cd "${TMPDIR}"

MOUNT="${PWD}/mount"
mkdir "${MOUNT}"

function cleanup() {
  set +o errexit
  if [ -n "${LOOPDEV:-}" ]; then
    losetup -d "${LOOPDEV}"
  fi
  if [ -n "${MOUNT:-}" ] && mountpoint -q "${MOUNT}"; then
    # We do not want risking deleting ex: the package cache
    umount --recursive "${MOUNT}" || exit 1
  fi
  if [ -n "${TMPDIR:-}" ]; then
    rm -rf "${TMPDIR}"
  fi
}
trap cleanup EXIT

function setup_disk() {
  truncate -s "${DISK_SIZE}" "${IMAGE}"
  sgdisk --clear \
    --new 1::+1M --typecode=1:ef02 \
    --new 2::-0 --typecode=2:8300 \
    "${IMAGE}"

  LOOPDEV=$(losetup --find --partscan --show "${IMAGE}")
  mkfs.btrfs "${LOOPDEV}p2"
  mount -o compress-force=zstd "${LOOPDEV}p2" "${MOUNT}"
}

function bootstrap() {
  cat <<EOF >pacman.conf
[options]
Architecture = auto

[core]
Include = mirrorlist

[extra]
Include = mirrorlist

[community]
Include = mirrorlist
EOF
  echo "Server = ${MIRROR}" >mirrorlist

  # We use the hosts package cache
  pacstrap -c -C pacman.conf -M "${MOUNT}" base linux grub openssh sudo polkit haveged netctl python btrfs-progs reflector
  cp mirrorlist "${MOUNT}/etc/pacman.d/"
}

function postinstall() {
  arch-chroot "${MOUNT}" /usr/bin/btrfs subvolume create /swap
  chattr +C "${MOUNT}/swap"
  chmod 0700 "${MOUNT}/swap"
  fallocate -l 512M "${MOUNT}/swap/swapfile"
  mkswap "${MOUNT}/swap/swapfile"
  echo -e "/swap/swapfile none swap defaults 0 0" >>"${MOUNT}/etc/fstab"

  echo "archlinux" >"${MOUNT}/etc/hostname"
  echo "KEYMAP=us" >"${MOUNT}/etc/vconsole.conf"
  ln -sf /var/run/systemd/resolve/resolv.conf "${MOUNT}/etc/resolv.conf"
}

function image_cleanup() {
  # Remove machine-id: see https://github.com/archlinux/arch-boxes/issues/25
  rm "${MOUNT}/etc/machine-id"

  # Remove pacman key ring for re-initialization
  rm -rf "${MOUNT}/etc/pacman.d/gnupg/"

  sync -f "${MOUNT}/etc/os-release"
  fstrim --verbose "${MOUNT}"
}

function mount_image() {
  LOOPDEV=$(losetup --find --partscan --show "${1:-${IMAGE}}")
  mount -o compress-force=zstd "${LOOPDEV}p2" "${MOUNT}"
  # Setup bind mount to package cache
  mount --bind "/var/cache/pacman/pkg" "${MOUNT}/var/cache/pacman/pkg"
}

function unmount_image() {
  umount --recursive "${MOUNT}"
  losetup -d "${LOOPDEV}"
  LOOPDEV=""
}

function copy_and_mount_image() {
  cp -a "${IMAGE}" "${1}"
  mount_image "${1}"
}

function mv_to_output() {
  sha256sum "${1}" >"${1}.SHA256"
  if [ -n "${SUDO_UID:-}" ]; then
    chown "${SUDO_UID}:${SUDO_GID}" "${1}"{,.SHA256}
  fi
  mv "${1}"{,.SHA256} "${OUTPUT}/"
}

# ${1} - new image file
# ${2} - final file
# ${3} - pre
# ${4} - post
function create_image() {
  copy_and_mount_image "${1}"
  "${3}"
  image_cleanup
  unmount_image
  "${4}" "${1}" "${2}"
  mv_to_output "${2}"
}

function cloud_image() {
  arch-chroot "${MOUNT}" /bin/bash < <(cat "${ORIG_PWD}"/http/install-{cloud,common}.sh)
  arch-chroot "${MOUNT}" /usr/bin/pacman -S --noconfirm linux-headers qemu-guest-agent cloud-init
  arch-chroot "${MOUNT}" /usr/bin/systemctl enable cloud-init-local.service cloud-init.service cloud-config.service cloud-final.service
}

function cloud_image_post() {
  qemu-img convert -c -f raw -O qcow2 "${1}" "${2}"
  rm "${1}"
}

function create_box() {
  TYPE="${1}"
  IMAGE_FILE="${2}"
  OUTPUT_FILE="${3}"
  mkdir box

  case "${TYPE}" in
    qemu)
      cat <<EOF >box/Vagrantfile
Vagrant.configure("2") do |config|
  config.vm.provider :libvirt do |libvirt|
    libvirt.driver = "kvm"
  end
end
EOF
      VIRTUAL_SIZE="$(grep -o "^[0-9]*" <<<"${DISK_SIZE}")"
      echo '{"format":"qcow2","provider":"libvirt","virtual_size":'"${VIRTUAL_SIZE}"'}' >box/metadata.json
      qemu-img convert -f raw -O qcow2 "${IMAGE_FILE}" "box/box.img"
      ;;
    virtualbox)
      # VirtualBox-6.1.12 src/VBox/NetworkServices/Dhcpd/Config.cpp line 276
      MAC_ADDRESS="080027$(openssl rand -hex 3 | tr '[:lower:]' '[:upper:]')"
      cat <<EOF >box/Vagrantfile
Vagrant.configure("2") do |config|
  config.vm.base_mac = "${MAC_ADDRESS}"
end
EOF
      echo '{"provider":"virtualbox"}' >box/metadata.json
      cp "${ORIG_PWD}/box.ovf" box/
      qemu-img convert -f raw -O vmdk "${IMAGE_FILE}" "box/packer-virtualbox.vmdk"

      sed -e "s/MACHINE_UUID/$(uuidgen)/" \
        -e "s/DISK_UUID/$(uuidgen)/" \
        -e "s/DISK_CAPACITY/$(qemu-img info --output=json "box/packer-virtualbox.vmdk" | jq '."virtual-size"')/" \
        -e "s/UNIX/$(date +%s)/" \
        -e "s/MAC_ADDRESS/${MAC_ADDRESS}/" \
        -i box/box.ovf
      ;;
    *)
      echo "Unknown box type: ${TYPE}"
      exit 1
      ;;
  esac

  rm "${IMAGE_FILE}"
  tar --xform 's:^box/::' -czf "${OUTPUT_FILE}" box/*
  rm -r box
}

function vagrant_qemu() {
  arch-chroot "${MOUNT}" /bin/bash < <(cat "${ORIG_PWD}"/http/install-{chroot,common}.sh)
  arch-chroot "${MOUNT}" /usr/bin/pacman -S --noconfirm linux-headers qemu-guest-agent
}

function vagrant_qemu_post() {
  create_box "qemu" "${1}" "${2}"
}

function vagrant_virtualbox() {
  arch-chroot "${MOUNT}" /bin/bash < <(cat "${ORIG_PWD}"/http/install-{chroot,common}.sh)
  arch-chroot "${MOUNT}" /usr/bin/pacman -S --noconfirm virtualbox-guest-utils-nox
  arch-chroot "${MOUNT}" /usr/bin/systemctl enable vboxservice
}

function vagrant_virtualbox_post() {
  create_box "virtualbox" "${1}" "${2}"
}

setup_disk
bootstrap
postinstall
# We run it here as it is the easiest solution and we do not want anything to go wrong!
arch-chroot "${MOUNT}" grub-install --target=i386-pc "${LOOPDEV}"
unmount_image

if [ -z "${BUILD_DATE:-}" ]; then
  BUILD_DATE="$(date -I)"
fi
create_image "cloud-img.img" "Arch-Linux-x86_64-cloudimg-${BUILD_DATE}.qcow2" cloud_image cloud_image_post
create_image "vagrant-qemu.img" "Arch-Linux-x86_64-libvirt-${BUILD_DATE}.box" vagrant_qemu vagrant_qemu_post
create_image "vagrant-virtualbox.img" "Arch-Linux-x86_64-virtualbox-${BUILD_DATE}.box" vagrant_qemu vagrant_virtualbox_post
