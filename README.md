# arch-boxes
[![CI Status](https://gitlab.archlinux.org/archlinux/arch-boxes/badges/master/pipeline.svg)](https://gitlab.archlinux.org/archlinux/arch-boxes/-/pipelines)

Arch-boxes provides several different VM images.

The images is built daily and released biweekly (via [GitLab CI schedule](https://gitlab.archlinux.org/archlinux/arch-boxes/-/pipeline_schedules)) and synced to the mirrors.

## Images

### Vagrant
Vagrant images for the VirtualBox and Libvirt provider are released to [Vagrant Cloud](https://app.vagrantup.com/archlinux/boxes/archlinux).

### QCOW2 images
At the time of writing we offer two different QCOW2 images. The images are synced to the mirrors under the `images` directory, ex: https://geo.mirror.pkgbuild.com/images/.

#### Basic image
The basic image is meant for local usage and comes preconfigured with the user `arch` (pw: `arch`) and sshd running.

#### Cloud image
The cloud image is meant to be used in "the cloud" and comes with [`cloud-init`](https://cloud-init.io/) preinstalled. For tested cloud providers and instructions please see the [ArchWiki's Arch Linux on a VPS page](https://wiki.archlinux.org/title/Arch_Linux_on_a_VPS#Official_Arch_Linux_cloud_image).

## Development

### Dependencies
You'll need the following dependencies:

* qemu
* libisoburn

### How to build this
The official builds are done in our Arch Linux GitLab CI and can be built locally by running:

    ./build-host.sh
