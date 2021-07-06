#!/bin/bash
# build-host.sh runs build-inside-vm.sh in a qemu VM running the latest Arch installer iso
#
# nounset: "Treat unset variables and parameters [...] as an error when performing parameter expansion."
# errexit: "Exit immediately if [...] command exits with a non-zero status."
set -o nounset -o errexit
readonly MIRROR="https://mirror.pkgbuild.com"

function init() {
  readonly ORIG_PWD="${PWD}"
  readonly OUTPUT="${PWD}/output"
  local tmpdir
  tmpdir="$(mktemp --dry-run --directory --tmpdir="${PWD}/tmp")"
  readonly TMPDIR="${tmpdir}"
  mkdir -p "${OUTPUT}" "${TMPDIR}"

  cd "${TMPDIR}"

  sudo pacman -Sy --noconfirm qemu-headless edk2-ovmf xorriso
}

# Do some cleanup when the script exits
function cleanup() {
  rm -rf "${TMPDIR}"
  jobs -p | xargs --no-run-if-empty kill
}
trap cleanup EXIT

# Use local Arch iso or download the latest iso and extract the relevant files
function prepare_boot() {
  if LOCAL_ISO="$(ls "${ORIG_PWD}/"archlinux-*-x86_64.iso 2>/dev/null)"; then
    echo "Using local iso: ${LOCAL_ISO}"
    ISO="${LOCAL_ISO}"
  fi

  if [ -z "${LOCAL_ISO}" ]; then
    LATEST_ISO="$(curl -fs "${MIRROR}/iso/latest/" | grep -Eo 'archlinux-[0-9]{4}\.[0-9]{2}\.[0-9]{2}-x86_64.iso' | head -n 1)"
    if [ -z "${LATEST_ISO}" ]; then
      echo "Error: Couldn't find latest iso'"
      exit 1
    fi
    curl -fO "${MIRROR}/iso/latest/${LATEST_ISO}"
    ISO="${PWD}/${LATEST_ISO}"
  fi

  # We need to extract the kernel and initrd so we can set a custom cmdline:
  # console=ttyS0, so the kernel and systemd sends output to the serial.
  xorriso -osirrox on -indev "${ISO}" -extract arch/boot/x86_64 .
  ISO_VOLUME_ID="$(xorriso -indev "${ISO}" |& awk -F : '$1 ~ "Volume id" {print $2}' | tr -d "' ")"
}

function start_qemu() {
  # Used to communicate with qemu
  mkfifo guest.out guest.in
  # We could use a sparse file but we want to fail early
  fallocate -l 4G scratch-disk.img

  { qemu-system-x86_64 \
    -machine accel=kvm:tcg \
    -smp 4 \
    -m 2048 \
    -net nic \
    -net user \
    -kernel vmlinuz-linux \
    -initrd initramfs-linux.img \
    -append "archisobasedir=arch archisolabel=${ISO_VOLUME_ID} cow_spacesize=2G ip=dhcp net.ifnames=0 console=ttyS0 mirror=${MIRROR}" \
    -drive file=scratch-disk.img,format=raw,if=virtio \
    -drive file="${ISO}",format=raw,if=virtio,media=cdrom,read-only \
    -virtfs "local,path=${ORIG_PWD},mount_tag=host,security_model=none" \
    -monitor none \
    -serial pipe:guest \
    -nographic || kill "${$}"; } &

  # We want to send the output to both stdout (fd1) and a new file descriptor (used by the expect function)
  exec 3>&1 {fd}< <(tee /dev/fd/3 <guest.out)
}

# Wait for a specific string from qemu
function expect() {
  local length="${#1}"
  local i=0
  local timeout="${2:-30}"
  # We can't use ex: grep as we could end blocking forever, if the string isn't followed by a newline
  while true; do
    # read should never exit with a non-zero exit code,
    # but it can happen if the fd is EOF or it times out
    IFS= read -r -u ${fd} -n 1 -t "${timeout}" c
    if [ "${1:${i}:1}" = "${c}" ]; then
      i="$((i + 1))"
      if [ "${length}" -eq "${i}" ]; then
        break
      fi
    else
      i=0
    fi
  done
}

# Send string to qemu
function send() {
  echo -en "${1}" >guest.in
}

function main() {
  init
  prepare_boot
  start_qemu

  # Login
  expect "archiso login:"
  send "root\n"
  expect "# "

  # Switch to bash and shutdown on error
  send "bash\n"
  expect "# "
  send "trap \"shutdown now\" ERR\n"
  expect "# "

  # Prepare environment
  send "mkdir /mnt/arch-boxes && mount -t 9p -o trans=virtio host /mnt/arch-boxes -oversion=9p2000.L\n"
  expect "# "
  send "mkfs.ext4 /dev/vda && mkdir /mnt/scratch-disk/ && mount /dev/vda /mnt/scratch-disk && cd /mnt/scratch-disk\n"
  expect "# "
  send "cp -a /mnt/arch-boxes/{box.ovf,build-inside-vm.sh,images} .\n"
  expect "# "
  send "mkdir pkg && mount --bind pkg /var/cache/pacman/pkg\n"
  expect "# "

  # Wait for pacman-init
  send "until systemctl is-active pacman-init; do sleep 1; done\n"
  expect "# "

  # Explicitly lookup mirror address as we'd get random failures otherwise during pacman
  send "curl -sSo /dev/null ${MIRROR}\n"
  expect "# "

  # Install required packages
  send "pacman -Syu --ignore linux --noconfirm qemu-headless jq\n"
  expect "# " 120 # (10/14) Updating module dependencies...

  # Downgrade util-linux to v2.36 as losetup (>=2.37)[1] uses
  # the LOOP_CONFIGURE ioctl which discard support is broken[2].
  # [1] https://github.com/karelzak/util-linux/pull/1152
  # [2] https://git.kernel.org/pub/scm/linux/kernel/git/axboe/linux-block.git/commit/?h=for-5.14/drivers&id=2b9ac22b12a266eb4fec246a07b504dd4983b16b
  send "pacman -U --noconfirm https://archive.archlinux.org/packages/u/util-linux/util-linux{,-libs}-2.36.2-1-x86_64.pkg.tar.zst\n"
  expect "# "

  ## Start build and copy output to local disk
  send "bash -x ./build-inside-vm.sh ${BUILD_VERSION:-}\n"
  expect "# " 240 # qemu-img convert can take a long time
  send "cp -vr --preserve=mode,timestamps output /mnt/arch-boxes/tmp/$(basename "${TMPDIR}")/\n"
  expect "# " 60
  mv output/* "${OUTPUT}/"

  # Shutdown the VM
  send "shutdown now\n"
  wait
}
main
