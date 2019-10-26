#!/bin/bash

set -e
set -x

sudo pacman -S --noconfirm cloud-init
sudo systemctl enable cloud-init-local.service
sudo systemctl enable cloud-init.service
sudo systemctl enable cloud-config.service
sudo systemctl enable cloud-final.service
