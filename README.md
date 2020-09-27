# arch-boxes
[![CI Status](https://gitlab.archlinux.org/archlinux/arch-boxes/badges/master/pipeline.svg)](https://gitlab.archlinux.org/archlinux/arch-boxes/-/pipelines)

- [Vagrant Cloud](https://app.vagrantup.com/archlinux/boxes/archlinux)
- [Download latest qcow2 image](https://gitlab.archlinux.org/archlinux/arch-boxes/-/jobs/artifacts/master/download?job=build:secure)

Arch-boxes provides automated builds of the Arch Linux releases for different providers and formats.

## Dependencies
You'll need the following dependencies:

* vagrant (for vagrant images)
* qemu

## How to build this
The official builds are done in our Arch Linux GitLab CI.

    ./build-host.sh

## Development workflow
Merge requests and general development shall be made on the `master` branch.

We have CI in place to build all images even for merge requests.

## Release workflow
Releases are done automatically via [GitLab CI schedule](https://gitlab.archlinux.org/archlinux/arch-boxes/-/pipeline_schedules).
No manual intervention is required or desired.

## Checking cloud-init support in our qcow2 images:
```bash
$ packer build -only=cloud -except=sign config.json
$ cp Arch-Linux-cloudimg-2020-02-24.qcow2 disk.qcow2

# Copied from (with minor changes): https://cloudinit.readthedocs.io/en/latest/topics/datasources/nocloud.html
$ { echo instance-id: iid-local01; echo local-hostname: cloudimg; } > meta-data

$ printf "#cloud-config\npassword: passw0rd\nchpasswd: { expire: False }\nssh_pwauth: True\n" > user-data

## create a disk to attach with some user-data and meta-data (require cdrkit)
$ genisoimage -output seed.iso -volid cidata -joliet -rock user-data meta-data

## create a new qcow image to boot, backed by your original image
$ qemu-img create -f qcow2 -b disk.qcow2 boot-disk.qcow2

## boot the image and login as 'arch' with password 'passw0rd'
## note, passw0rd was set as password through the user-data above,
## there is no password set on these images.
$ qemu-system-x86_64 -m 256 \
   -net nic -net user,hostfwd=tcp::2222-:22 \
   -drive file=boot-disk.qcow2,if=virtio \
   -drive file=seed.iso,if=virtio
```
