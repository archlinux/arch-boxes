#!/bin/bash

set -e
set -x

sudo pacman -S --noconfirm virtualbox-guest-utils-nox
sudo systemctl enable vboxservice
