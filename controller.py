#!/usr/bin/env python
#-*- encoding; utf-8 -*-
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
THIS_MONTH = int(datetime.datetime.now().strftime("%m"))
LEN_RELEASES = 2
CWD = '/srv/arch-boxes/arch-boxes'
ISO_PATH = '/srv/ftp/iso/latest/archlinux-' + datetime.datetime.now().strftime(
    "%Y.%m") + '.01-x86_64.iso'
ISO_CHECKSUM_PATH = '/srv/ftp/iso/latest/sha1sums.txt'


def main():
    are_resources_present()
    with urllib.request.urlopen(API_URL) as response:
        data = json.load(response)
        release_version = data['current_version']['version']
        release_providers = data['current_version']['providers']
        if not is_latest(release_version):
            subprocess.call([
                "/usr/bin/packer", "build", "parallel=false", "-var",
                "'headless=true'", "-var", "'write_zeroes=yes'",
                "-except=vmware-iso", "vagrant.json"
            ],
                            cwd=CWD)
        else:
            if not all_released(release_providers):
                determine_missing_release(release_providers)


def are_resources_present():
    if os.path.exists(ISO_PATH) and os.path.exists(ISO_CHECKSUM_PATH):
        pass
    else:
        sys.exit(1)


def determine_missing_release(release_providers):
    if release_providers[0]['name'] == 'virtualbox':
        subprocess.call([
            "/usr/bin/packer", "build", "parallel=false", "-var",
            "'headless=true'", "-var", "'write_zeroes=yes'",
            "-except=vmware-iso,virtualbox", "vagrant.json"
        ],
                        cwd=CWD)
    elif release_providers[0]['name'] == 'libvirt':
        subprocess.call([
            "/usr/bin/packer", "build", "parallel=false", "-var",
            "'headless=true'", "-var", "'write_zeroes=yes'",
            "-except=vmware-iso,qemu", "vagrant.json"
        ],
                        cwd=CWD)


def is_latest(release_version):
    release_month = int(release_version.split(".")[1])
    if THIS_MONTH > release_month:
        return False
    else:
        return True


def all_released(release_providers):
    if LEN_RELEASES > len(release_providers):
        return False
    else:
        return True


if __name__ == '__main__':
    main()
