#!/bin/bash

set -e
set -x

ln -sf /usr/share/zoneinfo/UTC /etc/localtime
sed -i -e 's/^#\(en_US.UTF-8\)/\1/' /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' >/etc/locale.conf

# setting the user credentials
echo -e "${NEWUSER}\n${NEWUSER}" | passwd
useradd -m -U "${NEWUSER}"
echo -e "${NEWUSER}\n${NEWUSER}" | passwd "${NEWUSER}"

# setting automatic authentication for any action requiring admin rights via Polkit
cat <<EOF >/etc/polkit-1/rules.d/49-nopasswd_global.rules
polkit.addRule(function(action, subject) {
    if (subject.isInGroup("${NEWUSER}")) {
        return polkit.Result.YES;
    }
});
EOF

# setting sudo for the user
cat <<EOF >"/etc/sudoers.d/${NEWUSER}"
Defaults:${NEWUSER} !requiretty
${NEWUSER} ALL=(ALL) NOPASSWD: ALL
EOF
chmod 440 "/etc/sudoers.d/${NEWUSER}"

# setup network
cat <<EOF >/etc/systemd/network/eth0.network
[Match]
Name=eth0

[Network]
DHCP=ipv4
EOF

# enabling important services
systemctl daemon-reload
systemctl enable sshd
systemctl enable haveged
systemctl enable systemd-networkd
systemctl enable systemd-resolved

pacman-key --init
pacman-key --populate archlinux

if [ -b "/dev/sda" ]; then
  grub-install /dev/sda
elif [ -b "/dev/vda" ]; then
  grub-install /dev/vda
fi
sed -i 's/^GRUB_TIMEOUT=.*$/GRUB_TIMEOUT=1/' /etc/default/grub
# setup unpredictable kernel names
sed -i 's/^GRUB_CMDLINE_LINUX=.*$/GRUB_CMDLINE_LINUX="net.ifnames=0"/' /etc/default/grub
sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT=\"rootflags=compress-force=zstd\"/' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

# lock root account
usermod -p "*" root

if declare -f post >/dev/null; then
  post
fi
