#!/bin/bash

set -e
set -x

cd "${OUTPUT}"
qemu-img convert -f qcow2 -O vmdk "${VM_NAME}" "${VM_NAME}.vmdk"
rm "${VM_NAME}"
cp ../box.ovf .
# VirtualBox-6.1.12 src/VBox/NetworkServices/Dhcpd/Config.cpp line 276
sed -e "s/MACHINE_UUID/$(uuidgen)/" \
  -e "s/DISK_UUID/$(uuidgen)/" \
  -e "s/DISK_CAPACITY/$(qemu-img info --output=json "${VM_NAME}.vmdk" | jq '."virtual-size"')/" \
  -e "s/UNIX/$(date +%s)/" \
  -e "s/MAC_ADDRESS/080027$(openssl rand -hex 3 | tr '[:lower:]' '[:upper:]')/" \
  -i box.ovf
