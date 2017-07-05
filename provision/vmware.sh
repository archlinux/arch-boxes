#!/bin/bash

set -e
set -x

sudo pacman -S --noconfirm open-vm-tools
sudo systemctl enable vmtoolsd
