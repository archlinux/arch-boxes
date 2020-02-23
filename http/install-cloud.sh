#!/bin/bash

set -e
set -x

ln -sf /usr/share/zoneinfo/UTC /etc/localtime
sed -i -e 's/^#\(en_US.UTF-8\)/\1/' /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' >/etc/locale.conf

# setting arch user credentials
echo -e 'arch\narch' | passwd
useradd -m -U arch
echo -e 'arch\narch' | passwd arch

# setting automatic authentication for any action requiring admin rights via Polkit
cat <<EOF >/etc/polkit-1/rules.d/49-nopasswd_global.rules
polkit.addRule(function(action, subject) {
    if (subject.isInGroup("arch")) {
        return polkit.Result.YES;
    }
});
EOF

# setting sudo for arch user
cat <<EOF >/etc/sudoers.d/arch
Defaults:arch !requiretty
arch ALL=(ALL) NOPASSWD: ALL
EOF
chmod 440 /etc/sudoers.d/arch

# setup unpredictable kernel names
ln -s /dev/null /etc/systemd/network/99-default.link

# setup network
cat <<EOF >/etc/systemd/network/eth0.network
[Match]
Name=eth0

[Network]
DHCP=ipv4
EOF

# Setup pacman-init.service for clean pacman keyring initialization
cat <<EOF >/etc/systemd/system/pacman-init.service
[Unit]
Description=Initializes Pacman keyring
Wants=haveged.service
After=haveged.service
Before=sshd.service
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
After=network.target
Wants=network.target
ConditionFirstBoot=yes

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=reflector --age 12 --protocol https --sort rate --save /etc/pacman.d/mirrorlist

[Install]
WantedBy=multi-user.target
EOF

# enabling important services
systemctl daemon-reload
systemctl enable sshd
systemctl enable haveged
systemctl enable systemd-networkd
systemctl enable systemd-resolved
systemctl enable pacman-init.service
systemctl enable reflector-init.service

if [ -b "/dev/sda" ]; then
  grub-install /dev/sda
elif [ -b "/dev/vda" ]; then
  grub-install /dev/vda
fi
sed -i -e 's/^GRUB_TIMEOUT=.*$/GRUB_TIMEOUT=1/' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg
