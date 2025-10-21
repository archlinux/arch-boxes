#!/bin/bash

# Misc "tweaks" done after bootstrapping
function pre() {
  # Remove machine-id see:
  # https://gitlab.archlinux.org/archlinux/arch-boxes/-/issues/25
  # https://gitlab.archlinux.org/archlinux/arch-boxes/-/issues/117
  rm "${MOUNT}/etc/machine-id"

  # Swap
  arch-chroot "${MOUNT}" /usr/bin/btrfs subvolume create /swap
  chattr +C "${MOUNT}/swap"
  chmod 0700 "${MOUNT}/swap"
  arch-chroot "${MOUNT}" /usr/bin/btrfs filesystem mkswapfile --size 512m --uuid clear /swap/swapfile
  echo -e "/swap/swapfile none swap defaults 0 0" >>"${MOUNT}/etc/fstab"

  arch-chroot "${MOUNT}" /usr/bin/systemd-firstboot --locale=C.UTF-8 --timezone=UTC --hostname=archlinux --keymap=us
  ln -sf /run/systemd/resolve/stub-resolv.conf "${MOUNT}/etc/resolv.conf"

  # Setup pacman-init.service for clean pacman keyring initialization
  cat <<EOF >"${MOUNT}/etc/systemd/system/pacman-init.service"
[Unit]
Description=Initializes Pacman keyring
Before=sshd.service cloud-final.service archlinux-keyring-wkd-sync.service
After=time-sync.target
ConditionFirstBoot=yes

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/pacman-key --init
ExecStart=/usr/bin/pacman-key --populate

[Install]
WantedBy=multi-user.target
EOF

  # Setup mirror list to worldwide mirrors
  cat <<'EOF' >"${MOUNT}/etc/pacman.d/mirrorlist"
Server = https://fastly.mirror.pkgbuild.com/$repo/os/$arch
Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch
EOF

  # enabling important services
  arch-chroot "${MOUNT}" /bin/bash -e <<EOF
source /etc/profile
systemctl enable sshd
systemctl enable systemd-networkd
systemctl enable systemd-resolved
systemctl enable systemd-timesyncd
systemctl enable systemd-time-wait-sync
systemctl enable pacman-init.service
EOF

  # GRUB
  arch-chroot "${MOUNT}" /usr/bin/grub-install --target=i386-pc "${LOOPDEV}"
  arch-chroot "${MOUNT}" /usr/bin/grub-install --target=x86_64-efi --efi-directory=/efi --removable
  sed -i 's/^GRUB_TIMEOUT=.*$/GRUB_TIMEOUT=1/' "${MOUNT}/etc/default/grub"
  # setup unpredictable kernel names
  sed -i 's/^GRUB_CMDLINE_LINUX=.*$/GRUB_CMDLINE_LINUX="net.ifnames=0"/' "${MOUNT}/etc/default/grub"
  sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT=\"rootflags=compress=zstd:1\"/' "${MOUNT}/etc/default/grub"
  arch-chroot "${MOUNT}" /usr/bin/grub-mkconfig -o /boot/grub/grub.cfg
}
