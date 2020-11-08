# arch-boxes
[![CI Status](https://gitlab.archlinux.org/archlinux/arch-boxes/badges/master/pipeline.svg)](https://gitlab.archlinux.org/archlinux/arch-boxes/-/pipelines)

- [**Vagrant Cloud**](https://app.vagrantup.com/archlinux/boxes/archlinux)
- [**Download latest artifacts**](https://gitlab.archlinux.org/archlinux/arch-boxes/-/jobs/artifacts/master/browse/output?job=build:secure)

Arch-boxes provides automated builds of the Arch Linux releases for different providers and formats.

## Usage

### Vagrant
If you're a vagrant user, you can just go to [**our Vagrant Cloud page**](https://app.vagrantup.com/archlinux/boxes/archlinux) and follow the instructions there.

### Cloud image
If you want to run Arch Linux in the cloud, you can use our cloud-image, which is preconfigured to work in most cloud environments. It is built daily and can be downloaded [here](https://gitlab.archlinux.org/archlinux/arch-boxes/-/jobs/artifacts/master/browse/output?job=build:secure) (`Arch-Linux-x86_64-cloudimg-xxxxxxxx.xxxx.qcow2`).

The default user is `arch`.

If you are running the cloud-image with QEMU, it can in some cases\* be beneficial to run the [QEMU guest-agent](https://wiki.qemu.org/Features/GuestAgent). This can be done with the following user-data:
```yaml
#cloud-config
packages:
  - qemu-guest-agent
runcmd:
  - [ systemctl, daemon-reload ]
  - [ systemctl, enable, qemu-guest-agent ]
  - [ systemctl, start, qemu-guest-agent ]
```
*\*ex: when using [Proxmox](https://pve.proxmox.com/wiki/Qemu-guest-agent) or [oVirt](https://www.ovirt.org/develop/internal/guest-agent/understanding-guest-agents-and-other-tools.html). Please be aware, that the agent basically gives the host root access to the guest.*

Be advised, however, that our automatic builds are cleaned up after a few days so you can't hard-code a specific image version anywhere.

You can use this snippet to always get the most recent image and check its integrity (you need to install `hq` for this):

    most_recent=$(curl -Ls 'https://gitlab.archlinux.org/archlinux/arch-boxes/-/jobs/artifacts/master/browse/output?job=build:secure' | grep cloudimg | grep -vi sha256 | hq a attr href | sed "s|artifacts/file|artifacts/raw|")
    curl -LO  "https://gitlab.archlinux.org$most_recent"{,.SHA256}
    sha256sum -c $(basename $most_recent).SHA256

## Development

### Dependencies
You'll need the following dependencies:

* vagrant (for vagrant images)
* qemu

### How to build this
The official builds are done in our Arch Linux GitLab CI.

    ./build-host.sh

## Development workflow
Merge requests and general development shall be made on the `master` branch.

We have CI in place to build all images even for merge requests.

## Release workflow
Releases are done automatically via [GitLab CI schedule](https://gitlab.archlinux.org/archlinux/arch-boxes/-/pipeline_schedules).
No manual intervention is required or desired.

## Checking cloud-init support in our cloud image:
Please see the example in `man cloud-localds`.
