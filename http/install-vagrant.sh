#!/bin/bash
# shellcheck disable=SC2034
NEWUSER="vagrant"

post() {
  # setting the user credentials
  useradd -m -U "${NEWUSER}"
  echo -e "${NEWUSER}\n${NEWUSER}" | passwd "${NEWUSER}"

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

  # install vagrant ssh key
  install --directory --owner=vagrant --group=vagrant --mode=0700 /home/vagrant/.ssh
  curl --output /home/vagrant/.ssh/authorized_keys --location https://raw.github.com/mitchellh/vagrant/master/keys/vagrant.pub
  chown vagrant:vagrant /home/vagrant/.ssh/authorized_keys
  chmod 0600 /home/vagrant/.ssh/authorized_keys
}
