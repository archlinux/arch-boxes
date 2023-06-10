# arch-boxes
[![CI Status](https://gitlab.archlinux.org/archlinux/arch-boxes/badges/master/pipeline.svg)](https://gitlab.archlinux.org/archlinux/arch-boxes/-/pipelines)

Arch-boxes provides several different VM images.

The images are built daily and released fortnightly (via [GitLab CI schedule](https://gitlab.archlinux.org/archlinux/arch-boxes/-/pipeline_schedules)) and synced to the mirrors.

## Images

### Vagrant
Vagrant images for the VirtualBox and Libvirt provider are released to [Vagrant Cloud](https://app.vagrantup.com/archlinux/boxes/archlinux).

### QCOW2 images
At the time of writing we offer two different QCOW2 images. The images are synced to the mirrors under the `images` directory, e.g.: https://geo.mirror.pkgbuild.com/images/.

#### Basic image
The basic image is meant for local usage and comes preconfigured with the user `arch` (password: `arch`) and sshd running.

#### Cloud image
The cloud image is meant to be used in "the cloud" and comes with [`cloud-init`](https://cloud-init.io/) preinstalled. For tested cloud providers and instructions please see the [ArchWiki's Arch Linux on a VPS page](https://wiki.archlinux.org/title/Arch_Linux_on_a_VPS#Official_Arch_Linux_cloud_image).

## Development

### Dependencies
You'll need the following dependencies:

* qemu
* libisoburn

### How to build this
The official builds are done in our Arch Linux GitLab CI and can be built locally by running (as root):

    ./build.sh

# Releases

Every release is signed by our CI with the following key:
```
-----BEGIN PGP PUBLIC KEY BLOCK-----

mDMEYpOJrBYJKwYBBAHaRw8BAQdAcSZilBvR58s6aD2qgsDE7WpvHQR2R5exQhNQ
yuILsTq0JWFyY2gtYm94ZXMgPGFyY2gtYm94ZXNAYXJjaGxpbnV4Lm9yZz6IkAQT
FggAOBYhBBuaFphKToy0SHEtKuC3i/QybG+PBQJik4msAhsBBQsJCAcCBhUKCQgL
AgQWAgMBAh4BAheAAAoJEOC3i/QybG+P81YA/A7HUftMGpzlJrPYBFPqW0nFIh7m
sIZ5yXxh7cTgqtJ7AQDFKSrulrsDa6hsqmEC11PWhv1VN6i9wfRvb1FwQPF6D7gz
BGKTiecWCSsGAQQB2kcPAQEHQBzLxT2+CwumKUtfi9UEXMMx/oGgpjsgp2ehYPBM
N8ejiPUEGBYIACYWIQQbmhaYSk6MtEhxLSrgt4v0MmxvjwUCYpOJ5wIbAgUJCWYB
gACBCRDgt4v0Mmxvj3YgBBkWCAAdFiEEZW5MWsHMO4blOdl+NDY1poWakXQFAmKT
iecACgkQNDY1poWakXTwaQEAwymt4PgXltHUH8GVUB6Xu7Gb5o6LwV9fNQJc1CMl
7CABAJw0We0w1q78cJ8uWiomE1MHdRxsuqbuqtsCn2Dn6/0Cj+4A/Apcqm7uzFam
pA5u9yvz1VJBWZY1PRBICBFSkuRtacUCAQC7YNurPPoWDyjiJPrf0Vzaz8UtKp0q
BSF/a3EoocLnCA==
=APeC
-----END PGP PUBLIC KEY BLOCK-----
```
