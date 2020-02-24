#!/bin/bash
# shellcheck disable=SC2034
NEWUSER="vagrant"

post() {
  # install vagrant ssh key
  install --directory --owner=vagrant --group=vagrant --mode=0700 /home/vagrant/.ssh
  curl --output /home/vagrant/.ssh/authorized_keys --location https://raw.github.com/mitchellh/vagrant/master/keys/vagrant.pub
  chown vagrant:vagrant /home/vagrant/.ssh/authorized_keys
  chmod 0600 /home/vagrant/.ssh/authorized_keys
}
