#!/bin/bash
# build-inside-vm.sh builds the images (cloud image, vagrant boxes)

# nounset: "Treat unset variables and parameters [...] as an error when performing parameter expansion."
# errexit: "Exit immediately if [...] command exits with a non-zero status."
set -o nounset -o errexit
readonly DISK_SIZE="2G"
readonly IMAGE="image.img"
# shellcheck disable=SC2016
readonly MIRROR='https://mirror.pkgbuild.com/$repo/os/$arch'

function init() {
  readonly ORIG_PWD="${PWD}"
  readonly OUTPUT="${PWD}/output"
  readonly TMPDIR="$(mktemp --dry-run --directory --tmpdir="${PWD}/tmp")"
  mkdir -p "${OUTPUT}" "${TMPDIR}"
  if [ -n "${SUDO_UID:-}" ]; then
    chown "${SUDO_UID}:${SUDO_GID}" "${OUTPUT}" "${TMPDIR}"
  fi
  cd "${TMPDIR}"

  readonly MOUNT="${PWD}/mount"
  mkdir "${MOUNT}"
}

# Do some cleanup when the script exits
function cleanup() {
  # We want all the commands to run, even if one of them fails.
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

# Create the disk, partitions it, format the partition and mount the filesystem
function setup_disk() {
  truncate -s "${DISK_SIZE}" "${IMAGE}"
  sgdisk --clear \
    --new 1::+1M --typecode=1:ef02 \
    --new 2::-0 --typecode=2:8300 \
    "${IMAGE}"

  LOOPDEV=$(losetup --find --partscan --show "${IMAGE}")
  # Partscan is racy
  wait_until_settled "${LOOPDEV}"
  mkfs.btrfs "${LOOPDEV}p2"
  mount -o compress-force=zstd "${LOOPDEV}p2" "${MOUNT}"
}

# Install Arch Linux to the filesystem (bootstrap)
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
  pacstrap -c -C pacman.conf -M "${MOUNT}" base linux grub openssh sudo polkit haveged btrfs-progs reflector
  cp mirrorlist "${MOUNT}/etc/pacman.d/"
}

# Misc "tweaks" done after bootstrapping
function postinstall() {
  arch-chroot "${MOUNT}" /usr/bin/btrfs subvolume create /swap
  chattr +C "${MOUNT}/swap"
  chmod 0700 "${MOUNT}/swap"
  fallocate -l 512M "${MOUNT}/swap/swapfile"
  mkswap "${MOUNT}/swap/swapfile"
  echo -e "/swap/swapfile none swap defaults 0 0" >>"${MOUNT}/etc/fstab"

  echo "COMPRESSION=\"xz\"" >>"${MOUNT}/etc/mkinitcpio.conf"
  arch-chroot "${MOUNT}" /usr/bin/mkinitcpio -p linux

  echo "archlinux" >"${MOUNT}/etc/hostname"
  echo "KEYMAP=us" >"${MOUNT}/etc/vconsole.conf"
  ln -sf /var/run/systemd/resolve/resolv.conf "${MOUNT}/etc/resolv.conf"
}

# Cleanup the image and trim it
function image_cleanup() {
  # Remove pacman key ring for re-initialization
  rm -rf "${MOUNT}/etc/pacman.d/gnupg/"

  sync -f "${MOUNT}/etc/os-release"
  fstrim --verbose "${MOUNT}"
}

# Helper function: wait until a given loop device has settled
# ${1} - loop device
function wait_until_settled() {
  udevadm settle
  blockdev --flushbufs --rereadpt ${1}
  until test -e "${1}p2"; do
      echo "${1}p2 doesn't exist yet..."
      sleep 1
  done
}

# Mount image helper (loop device + mount)
function mount_image() {
  LOOPDEV=$(losetup --find --partscan --show "${1:-${IMAGE}}")
  # Partscan is racy
  wait_until_settled ${LOOPDEV}
  mount -o compress-force=zstd "${LOOPDEV}p2" "${MOUNT}"
  # Setup bind mount to package cache
  mount --bind "/var/cache/pacman/pkg" "${MOUNT}/var/cache/pacman/pkg"
}

# Unmount image helper (umount + detach loop device)
function unmount_image() {
  umount --recursive "${MOUNT}"
  losetup -d "${LOOPDEV}"
  LOOPDEV=""
}

# Copy image and mount the copied image
function copy_and_mount_image() {
  cp -a "${IMAGE}" "${1}"
  mount_image "${1}"
}

# Compute SHA256, adjust owner to $SUDO_UID:$SUDO_UID and move to output/
function mv_to_output() {
  sha256sum "${1}" >"${1}.SHA256"
  if [ -n "${SUDO_UID:-}" ]; then
    chown "${SUDO_UID}:${SUDO_GID}" "${1}"{,.SHA256}
  fi
  mv "${1}"{,.SHA256} "${OUTPUT}/"
}

# Helper function: create a new image from the "base" image
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
  arch-chroot "${MOUNT}" /usr/bin/pacman -S --noconfirm qemu-guest-agent cloud-init
  arch-chroot "${MOUNT}" /usr/bin/systemctl enable cloud-init-local.service cloud-init.service cloud-config.service cloud-final.service
}

function cloud_image_post() {
  qemu-img convert -c -f raw -O qcow2 "${1}" "${2}"
  rm "${1}"
}

function vagrant_qemu() {
  arch-chroot "${MOUNT}" /bin/bash < <(cat "${ORIG_PWD}"/http/install-{chroot,common}.sh)
  arch-chroot "${MOUNT}" /usr/bin/pacman -S --noconfirm netctl qemu-guest-agent
}

function vagrant_qemu_post() {
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

function vagrant_virtualbox() {
  arch-chroot "${MOUNT}" /bin/bash < <(cat "${ORIG_PWD}"/http/install-{chroot,common}.sh)
  arch-chroot "${MOUNT}" /usr/bin/pacman -S --noconfirm netctl virtualbox-guest-utils-nox
  arch-chroot "${MOUNT}" /usr/bin/systemctl enable vboxservice
}

function vagrant_virtualbox_post() {
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

# ${1} - Optional build version. If not set, will generate a default based on date.
function main() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "root is required"
    exit 1
  fi
  init

  setup_disk
  bootstrap
  postinstall
  # We run it here as it is the easiest solution and we do not want anything to go wrong!
  arch-chroot "${MOUNT}" grub-install --target=i386-pc "${LOOPDEV}"
  unmount_image

  local build_version
  if [ -z "${1:-}" ]; then
    build_version="$(date +%Y%m%d).0"
    echo "WARNING: BUILD_VERSION wasn't set!"
    echo "Falling back to $build_version"
  else
    build_version="${1}"
  fi
  create_image "cloud-img.img" "Arch-Linux-x86_64-cloudimg-${build_version}.qcow2" cloud_image cloud_image_post
  create_image "vagrant-qemu.img" "Arch-Linux-x86_64-libvirt-${build_version}.box" vagrant_qemu vagrant_qemu_post
  create_image "vagrant-virtualbox.img" "Arch-Linux-x86_64-virtualbox-${build_version}.box" vagrant_qemu vagrant_virtualbox_post
}
main "$@"
