#!/usr/bin/env python
# -*- encoding; utf-8 -*-
#
# Author: Christian Rebischke <chris.rebischke@archlinux.org>
# This file is licensed under GPLv3

import urllib.request
import json
import datetime
import sys
import subprocess
import os.path

API_URL = 'https://app.vagrantup.com/api/v1/box/archlinux/archlinux'
NOW = datetime.datetime.now()
THIS_MONTH = int(NOW.strftime("%m"))
LEN_RELEASES = 2
CWD = '/srv/arch-boxes/arch-boxes'
ISO_PATH = '/srv/ftp/iso/latest/archlinux-' + NOW.strftime(
    "%Y.%m") + '.01-x86_64.iso'
ISO_CHECKSUM_PATH = '/srv/ftp/iso/latest/sha1sums.txt'
PACKER_CMD_TEMPLATE = [
    "/usr/bin/packer", "build", "-parallel=false", "-var", "'headless=true'",
    "-var", "'write_zeroes=yes'", "-except=vmware-iso", "vagrant.json"
]


def main():
    exit_if_resources_present()
    with urllib.request.urlopen(API_URL) as response:
        data = json.load(response)
        release_version = data['current_version']['version']
        release_providers = data['current_version']['providers']
        if not is_latest(release_version):
            subprocess.call(PACKER_CMD_TEMPLATE, cwd=CWD)
        else:
            if not all_released(release_providers):
                determine_missing_release(release_providers)


def exit_if_resources_present():
    if os.path.exists(ISO_PATH) and os.path.exists(ISO_CHECKSUM_PATH):
        pass
    else:
        sys.exit(0)


def build_packer_call(provider):
    provider_map = {"virtualbox": "virtualbox", "libvirt": "qemu"}
    packer = PACKER_CMD_TEMPLATE.copy()
    packer[7] += ","
    packer[7] += provider_map[provider]
    return packer


def determine_missing_release(release_providers):
    subprocess.call(build_packer_call(release_providers[0]['name']), cwd=CWD)


def is_latest(release_version):
    release_month = int(release_version.split(".")[1])
    return THIS_MONTH <= release_month


def all_released(release_providers):
    return LEN_RELEASES <= len(release_providers)


if __name__ == '__main__':
    main()
