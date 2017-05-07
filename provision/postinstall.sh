#!/bin/bash

set -e
set -x

# setting hostname, locales, etc
hostnamectl set-hostname "archlinux"
localectl set-locale "LANG=en_US.UTF-8"
localectl set-keymap "us"
localectl set-x11-keymap "us"
timedatectl set-ntp true
