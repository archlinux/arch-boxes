#!/bin/bash

set -e
set -x

# setting hostname, locales, etc
hostnamectl set-hostname "archlinux"
localectl set-keymap "us"
timedatectl set-ntp true

#setting link to systemd-resolved
ln -sf /var/run/systemd/resolve/resolv.conf /etc/resolv.conf
