#!/bin/bash

function vagrant_common() {
  local NEWUSER="vagrant"
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
curl --output /home/vagrant/.ssh/authorized_keys --location https://github.com/hashicorp/vagrant/raw/main/keys/vagrant.pub
# WARNING: Please only update the hash if you are 100% sure it was intentionally updated by upstream.
sha256sum -c <<< "9aa9292172c915821e29bcbf5ff42d4940f59d6a148153c76ad638f5f4c6cd8b /home/vagrant/.ssh/authorized_keys"
chown vagrant:vagrant /home/vagrant/.ssh/authorized_keys
chmod 0600 /home/vagrant/.ssh/authorized_keys
EOF
}
