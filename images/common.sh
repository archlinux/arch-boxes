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
  cat <<EOF >"${MOUNT}/etc/systemd/network/80-dhcp.network"
[Match]
Name=en*
Name=eth*

[Link]
RequiredForOnline=routable

[Network]
DHCP=yes
EOF

  # install vagrant ssh key
  arch-chroot "${MOUNT}" /bin/bash -e <<EOF
install --directory --owner=vagrant --group=vagrant --mode=0700 /home/vagrant/.ssh
curl --output /home/vagrant/.ssh/authorized_keys --location https://github.com/hashicorp/vagrant/raw/main/keys/vagrant.pub
# WARNING: Please only update the hash if you are 100% sure it was intentionally updated by upstream.
sha256sum -c <<< "55009a554ba2d409565018498f1ad5946854bf90fa8d13fd3fdc2faa102c1122 /home/vagrant/.ssh/authorized_keys"
chown vagrant:vagrant /home/vagrant/.ssh/authorized_keys
chmod 0600 /home/vagrant/.ssh/authorized_keys
EOF
}
