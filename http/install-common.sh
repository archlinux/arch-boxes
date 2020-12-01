#!/bin/bash

set -e
set -x

# Setup pacman-init.service for clean pacman keyring initialization
cat <<EOF >/etc/systemd/system/pacman-init.service
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
cat <<EOF >/etc/systemd/system/reflector-init.service
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
systemctl enable sshd
systemctl enable haveged
systemctl enable systemd-networkd
systemctl enable systemd-resolved
systemctl enable systemd-timesyncd
systemctl enable pacman-init.service
systemctl enable reflector-init.service

sed -i 's/^GRUB_TIMEOUT=.*$/GRUB_TIMEOUT=1/' /etc/default/grub
# setup unpredictable kernel names
sed -i 's/^GRUB_CMDLINE_LINUX=.*$/GRUB_CMDLINE_LINUX="net.ifnames=0"/' /etc/default/grub
sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT=\"rootflags=compress-force=zstd\"/' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

if declare -f post >/dev/null; then
  post
fi
