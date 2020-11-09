#!/bin/bash
# build-inside-vm.sh builds the images (cloud image, vagrant boxes)

# nounset: "Treat unset variables and parameters [...] as an error when performing parameter expansion."
# errexit: "Exit immediately if [...] command exits with a non-zero status."
set -o nounset -o errexit
readonly DISK_SIZE="20G"
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
  pacstrap -c -C pacman.conf -M "${MOUNT}" base linux grub openssh sudo haveged btrfs-progs reflector
  cp mirrorlist "${MOUNT}/etc/pacman.d/"
}

# Misc "tweaks" done after bootstrapping
function postinstall() {
  # Remove machine-id see:
  # https://gitlab.archlinux.org/archlinux/arch-boxes/-/issues/25
  # https://gitlab.archlinux.org/archlinux/arch-boxes/-/issues/117
  rm "${MOUNT}/etc/machine-id"

  arch-chroot "${MOUNT}" /usr/bin/btrfs subvolume create /swap
  chattr +C "${MOUNT}/swap"
  chmod 0700 "${MOUNT}/swap"
  fallocate -l 512M "${MOUNT}/swap/swapfile"
  mkswap "${MOUNT}/swap/swapfile"
  echo -e "/swap/swapfile none swap defaults 0 0" >>"${MOUNT}/etc/fstab"

  echo "COMPRESSION=\"zstd\"" >>"${MOUNT}/etc/mkinitcpio.conf"
  arch-chroot "${MOUNT}" /usr/bin/mkinitcpio -p linux

  sed -i -e 's/^#\(en_US.UTF-8\)/\1/' "${MOUNT}/etc/locale.gen"
  arch-chroot "${MOUNT}" /usr/bin/locale-gen
  arch-chroot "${MOUNT}" /usr/bin/systemd-firstboot --locale=en_US.UTF-8 --timezone=UTC --hostname=archlinux --keymap=us
  ln -sf /run/systemd/resolve/stub-resolv.conf "${MOUNT}/etc/resolv.conf"

  # Setup pacman-init.service for clean pacman keyring initialization
  cat <<EOF >"${MOUNT}/etc/systemd/system/pacman-init.service"
[Unit]
Description=Initializes Pacman keyring
Wants=haveged.service
After=haveged.service
Before=sshd.service cloud-final.service
ConditionFirstBoot=yes

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/pacman-key --init
ExecStart=/usr/bin/pacman-key --populate archlinux

[Install]
WantedBy=multi-user.target
EOF

  # Add service for running reflector on first boot
  cat <<EOF >"${MOUNT}/etc/systemd/system/reflector-init.service"
[Unit]
Description=Initializes mirrors for the VM
After=network-online.target
Wants=network-online.target
Before=sshd.service cloud-final.service
ConditionFirstBoot=yes

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist

[Install]
WantedBy=multi-user.target
EOF

  # enabling important services
  arch-chroot "${MOUNT}" /bin/bash -e <<EOF
. /etc/profile
systemctl enable sshd
systemctl enable haveged
systemctl enable systemd-networkd
systemctl enable systemd-resolved
systemctl enable systemd-timesyncd
systemctl enable pacman-init.service
systemctl enable reflector-init.service
EOF

  # GRUB
  arch-chroot "${MOUNT}" /usr/bin/grub-install --target=i386-pc "${LOOPDEV}"
  sed -i 's/^GRUB_TIMEOUT=.*$/GRUB_TIMEOUT=1/' "${MOUNT}/etc/default/grub"
  # setup unpredictable kernel names
  sed -i 's/^GRUB_CMDLINE_LINUX=.*$/GRUB_CMDLINE_LINUX="net.ifnames=0"/' "${MOUNT}/etc/default/grub"
  sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT=\"rootflags=compress-force=zstd\"/' "${MOUNT}/etc/default/grub"
  arch-chroot "${MOUNT}" /usr/bin/grub-mkconfig -o /boot/grub/grub.cfg
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
# ${1} - final file
# ${2} - pre
# ${3} - post
function create_image() {
  local tmp_image="$(basename "$(mktemp -u)")"
  copy_and_mount_image "${tmp_image}"
  "${2}"
  image_cleanup
  unmount_image
  "${3}" "${tmp_image}" "${1}"
  mv_to_output "${1}"
}

function cloud_image() {
  # The growpart module[1] requires the growpart program, provided by the
  # cloud-guest-utils package
  # [1] https://cloudinit.readthedocs.io/en/latest/topics/modules.html#growpart
  arch-chroot "${MOUNT}" /usr/bin/pacman -S --noconfirm cloud-init cloud-guest-utils
  arch-chroot "${MOUNT}" /usr/bin/systemctl enable cloud-init-local.service cloud-init.service cloud-config.service cloud-final.service
}

function cloud_image_post() {
  qemu-img convert -c -f raw -O qcow2 "${1}" "${2}"
  rm "${1}"
}

function vagrant_common() {
  arch-chroot "${MOUNT}" /usr/bin/pacman -S --noconfirm netctl polkit

  NEWUSER="vagrant"
  # setting the user credentials
  arch-chroot "${MOUNT}" /usr/bin/useradd -m -U "${NEWUSER}"
  echo -e "${NEWUSER}\n${NEWUSER}" | arch-chroot "${MOUNT}" /usr/bin/passwd "${NEWUSER}"

  # setting sudo for the user
  cat <<EOF >"${MOUNT}/etc/sudoers.d/${NEWUSER}"
Defaults:${NEWUSER} !requiretty
${NEWUSER} ALL=(ALL) NOPASSWD: ALL
EOF
  chmod 440 "${MOUNT}/etc/sudoers.d/${NEWUSER}"

  # setup network
  cat <<EOF >"${MOUNT}/etc/systemd/network/eth0.network"
[Match]
Name=eth0

[Network]
DHCP=ipv4
EOF

  # install vagrant ssh key
  arch-chroot "${MOUNT}" /bin/bash -e <<EOF
install --directory --owner=vagrant --group=vagrant --mode=0700 /home/vagrant/.ssh
curl --output /home/vagrant/.ssh/authorized_keys --location https://raw.github.com/mitchellh/vagrant/master/keys/vagrant.pub
chown vagrant:vagrant /home/vagrant/.ssh/authorized_keys
chmod 0600 /home/vagrant/.ssh/authorized_keys
EOF

  # setting automatic authentication for any action requiring admin rights via Polkit
  cat <<EOF >"${MOUNT}/etc/polkit-1/rules.d/49-nopasswd_global.rules"
polkit.addRule(function(action, subject) {
    if (subject.isInGroup("vagrant")) {
        return polkit.Result.YES;
    }
});
EOF
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
  vagrant_common
  arch-chroot "${MOUNT}" /usr/bin/pacman -S --noconfirm virtualbox-guest-utils-nox
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
  unmount_image

  local build_version
  if [ -z "${1:-}" ]; then
    build_version="$(date +%Y%m%d).0"
    echo "WARNING: BUILD_VERSION wasn't set!"
    echo "Falling back to $build_version"
  else
    build_version="${1}"
  fi
  create_image "Arch-Linux-x86_64-cloudimg-${build_version}.qcow2" cloud_image cloud_image_post
  create_image "Arch-Linux-x86_64-libvirt-${build_version}.box" vagrant_common vagrant_qemu_post
  create_image "Arch-Linux-x86_64-virtualbox-${build_version}.box" vagrant_virtualbox vagrant_virtualbox_post
}
main "$@"
