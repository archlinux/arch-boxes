# arch-boxes
[![Build Status](https://travis-ci.org/archlinux/arch-boxes.svg?branch=master)](https://travis-ci.org/archlinux/arch-boxes)

Arch-boxes provides automated builds of the Arch Linux releases for
different providers and post-processors. Check the providers or post-processor sections if you want to know
which are currently supported.

## Dependencies

You'll need the following dependencies:

* packer (for basic usage)
* vagrant (for vagrant images)
* qemu (for libvirt provider support)
* virtualbox (for virtualbox support)
* VMware Workstation Pro (for vmware support)

## variables
Here is an overview over all variables you can set in `vagrant.json` or
`local.json`:

* `iso_url`: the url to the ISO. This can be an url or a filepath
  beginning with `file://`
* `iso_checksum_url`: the url to the checksum file. This can be an url
  or a filepath beginning with `file://`
* `iso_checksum_type`: this specifies the hashing algorithm for the
  checksum.
* `disk_size`: this specifices the disk size in bytes.
* `memory`: this specifies the size of the RAM in bytes.
* `cpus`: this specifies the number of cores for your VM.
* `headless`: this sets GUI on or off.
* `atlas_token`: here you can specify the atlas token for uploading your
  box to the vagrantcloud. If you don't have any atlas token you can
  ignore this variable. But then don't be suprised when the process
  fails. The boxes are build, they just haven't been uploaded.
* `write_zeroes`: this variable is empty. if you set any string in this
  variable it will fill the box with zeros to reduce the size. **DO NOT
  use this if you are running a SSD. It will harm your SSDs lifetime**
* `boot_wait`: this specifies the time packer should wait for booting up
  the ISO before entering any command.

## how to start the build process locally
Edit the `local.json` before you start the build. set the right
`iso_url` and the right `iso_checksum_url`. Then you can start the build
for virtualbox only with the following command:

On Arch Linux:

`packer-io build -only=virtualbox-iso -var-file=local.json vagrant.json`

On any other system:

`packer build -only=virtualbox-iso -var-file=local.json vagrant.json`

**Note** this is because of the name conflict with the AUR-Helpertool
`packer` on Arch Linux.

## how to start the build process for official builds
The official builds are done on our Arch Linux Buildserver.

On Arch Linux:

`packer-io build vagrant.json`

On any other system:

`packer build vagrant.json`

**Note:** this is because of the name conflict with the AUR-Helpertool
`packer` on Arch linux.

## providers

* virtualbox-iso
* qemu/libvirt
* vmware-iso

## post-processors

* vagrant

## Troubleshooting

### Parallel build fails
If the parallel build fails this is mostly because the KVM device is
already occupied by a different provider. You can use the build option
`parallel=false` for building the images in a queue instead of parallel.
But don't be surprised that that the build process will take longer. Any
other option is to disable KVM support for all other providers except
one.

Start `packer` with `-parallel=false`:

On Arch Linux:

`packer-io build -parallel=false vagrant.json`

On any other system:

`packer build -parallel=false vagrant.json`
