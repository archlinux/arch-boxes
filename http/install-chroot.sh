#!/bin/bash

set -e
set -x

ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hostnamectl set-hostname "archlinux"
sed -i -e 's/^#\(en_US.UTF-8\)/\1/' /etc/locale.gen
locale-gen
localectl set-locale "LANG=en_US.UTF-8"
localectl set-keymap "us"
localectl set-xx1-keymap "us"

# setting vagrant user credentials
echo -e 'vagrant\nvagrant' | passwd
useradd -m -U vagrant
echo -e 'vagrant\nvagrant' | passwd vagrant

# setting sudo for vagrant user
cat <<EOF > /etc/sudoers.d/vagrant
Defaults:vagrant !requiretty
vagrant ALL=(ALL) NOPASSWD: ALL
EOF
chmod 440 /etc/sudoers.d/vagrant

# install vagrant ssh key
install --directory --owner=vagrant --group=vagrant --mode=0700 /home/vagrant/.ssh
curl --output /home/vagrant/.ssh/authorized_keys --location https://raw.github.com/mitchellh/vagrant/master/keys/vagrant.pub
chown vagrant:vagrant /home/vagrant/.ssh/authorized_keys
chmod 0600 /home/vagrant/.ssh/authorized_keys

# enabling important services
systemctl enable sshd
systemctl enable systemd-networkd

grub-install "$device"
sed -i -e 's/^GRUB_TIMEOUT=.*$/GRUB_TIMEOUT=1/' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg
