# arch-boxes

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

## How to start the build process

On Arch Linux:

`packer-io build vagrant.json`

On any other System:

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
