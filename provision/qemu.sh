#!/bin/bash

set -e
set -x

sudo pacman -S --noconfirm linux-headers
sudo pacman -S --noconfirm qemu-guest-agent
