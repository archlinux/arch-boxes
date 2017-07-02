#!/bin/bash

set -e
set -x

sudo pacman -S --noconfirm virtualbox-guest-utils-nox virtualbox-guest-modules-arch
sudo systemctl enable vboxservice
