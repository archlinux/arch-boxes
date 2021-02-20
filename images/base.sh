#!/bin/bash

# Misc "tweaks" done after bootstrapping
function pre() {
  # Remove machine-id see:
  # https://gitlab.archlinux.org/archlinux/arch-boxes/-/issues/25
  # https://gitlab.archlinux.org/archlinux/arch-boxes/-/issues/117
  rm "${MOUNT}/etc/machine-id"

  arch-chroot "${MOUNT}" /usr/bin/btrfs subvolume create /swap
  chattr +C "${MOUNT}/swap"
  chmod 0700 "${MOUNT}/swap"
  fallocate -l 512M "${MOUNT}/swap/swapfile"
  chmod 0600 "${MOUNT}/swap/swapfile"
  mkswap "${MOUNT}/swap/swapfile"
  echo -e "/swap/swapfile none swap defaults 0 0" >>"${MOUNT}/etc/fstab"

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
source /etc/profile
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
