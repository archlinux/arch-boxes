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
* jq (for preprocessing packer json files at runtime if you choose)

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
* `vagrant_cloud_token`: here you can specify the vagrant cloud token for 
  uploading your box to the vagrantcloud. If you don't have a vagrant cloud 
  token you can ignore this variable. Without a token the boxes will be
  built, but the upload step step will fail.
* `write_zeroes`: this variable is empty. if you set any string in this
  variable it will fill the box with zeros to reduce the size. **DO NOT
  use this if you are running a SSD. It will harm your SSDs lifetime**
* `boot_wait`: this specifies the time packer should wait for booting up
  the ISO before entering any command.

## how to start the build process locally
Edit the `local.json` before you start the build. set the right
`iso_url` and the right `iso_checksum_url`. Then you can start the build
for virtualbox only with the following command:

```bash
jq '.["post-processors"][0] |= map(select(.type == "vagrant"))' vagrant.json > vagrant_local.json \
&& packer build -only=virtualbox-iso -var-file=local.json vagrant_local.json \
&& rm vagrant_local.json
```

`jq` is used to preprocess `vagrant.json` so that only the `vagrant` post-processor is triggered, thus skipping publishing build artifacts to Vagrant cloud. The reason `jq` isn't being piped into packer is because it's more stable to fully unbuffer into a temporary file (`vagrant_local.json`), then pass that file into the packer build, then remove it.

If you want to build and publish to Vagrant cloud, then run the following command:

`packer build -only=virtualbox-iso -var-file=local.json vagrant.json`

When packer outputs `Waiting for SSH to become available...`, then the VM is ready to accept an RDP connection. A few lines above that line should be the RDP URL. Copy-paste that URL into your favorite RDP client (Windows already comes with a decent one called `Windows Desktop Connection`), and open that connection. Now you're watching packer's boot commands execute.

TODO: Document how to use a text-only command line RDP client for Windows that can be run from Git Bash.

Add the built box to vagrant with the following command, except fix the date at the end:

`vagrant box add --name archlinux_base 'Arch-Linux-x86_64-virtualbox-2019-05-17.box'`

## how to start the build process for official builds
The official builds are done on our Arch Linux Buildserver.

`packer build vagrant.json`

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

`packer build -parallel=false vagrant.json`
