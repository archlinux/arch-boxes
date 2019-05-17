#!/bin/bash

set -e
set -x

sudo pacman -Syy
yes | sudo pacman -Syy virtualbox-guest-utils-nox virtualbox-guest-modules-arch
sudo systemctl enable vboxservice
