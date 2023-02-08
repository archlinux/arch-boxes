#!/bin/bash

function new_user_pass_same_as_name_and_vagrant_sshkey(){
  arch-chroot "${MOUNT}" /usr/bin/useradd -m -U "${1}"
  echo -e "${1}\n${1}" | arch-chroot "${MOUNT}" /usr/bin/passwd "${1}"

  # install vagrant ssh key
  arch-chroot "${MOUNT}" /bin/bash -e <<EOF
install --directory --owner=${1} --group=${1} --mode=0700 /home/${1}/.ssh
curl --output /home/vagrant/.ssh/authorized_keys --location https://github.com/hashicorp/vagrant/raw/main/keys/vagrant.pub
# WARNING: Please only update the hash if you are 100% sure it was intentionally updated by upstream.
# NOTE: why not store the files in this repo then?
sha256sum -c <<< "9aa9292172c915821e29bcbf5ff42d4940f59d6a148153c76ad638f5f4c6cd8b /home/vagrant/.ssh/authorized_keys"
chown ${1}:${1} /home/${1}/.ssh/authorized_keys
chmod 0600 /home/${1}/.ssh/authorized_keys
EOF
}

function vagrant_common() {
  new_user_pass_same_as_name_and_vagrant_sshkey "vagrant"

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

}
