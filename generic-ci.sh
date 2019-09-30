#!/bin/bash
set -x

case $1 in

  install)
    PACKER_CURRENT_VERSION="$(curl -s https://checkpoint-api.hashicorp.com/v1/check/packer | jq -r -M '.current_version')"
    PACKER_URL="https://releases.hashicorp.com/packer/$PACKER_CURRENT_VERSION/packer_${PACKER_CURRENT_VERSION}_linux_amd64.zip"
    PACKER_SHA256="https://releases.hashicorp.com/packer/$PACKER_CURRENT_VERSION/packer_${PACKER_CURRENT_VERSION}_SHA256SUMS"
    PACKER_SHA256_SIG="https://releases.hashicorp.com/packer/$PACKER_CURRENT_VERSION/packer_${PACKER_CURRENT_VERSION}_SHA256SUMS.sig"
    HASHICORP_FINGERPRINT=91a6e7f85d05c65630bef18951852d87348ffc4c
    HASHICORP_KEY="https://keybase.io/hashicorp/pgp_keys.asc?fingerprint=${HASHICORP_FINGERPRINT}"
    wget "${PACKER_URL}"
    wget "${PACKER_SHA256}"
    wget "${PACKER_SHA256_SIG}"
    wget -O hashicorp.key "${HASHICORP_KEY}"
    gpg --with-fingerprint --with-colons hashicorp.key | grep ${HASHICORP_FINGERPRINT^^}
    gpg --import hashicorp.key
    gpg --verify "packer_${PACKER_CURRENT_VERSION}_SHA256SUMS.sig" "packer_${PACKER_CURRENT_VERSION}_SHA256SUMS"
    grep linux_amd64 "packer_${PACKER_CURRENT_VERSION}_SHA256SUMS" > packer_SHA256SUM_linux_amd64
    sha256sum --check --status packer_SHA256SUM_linux_amd64
    unzip "packer_${PACKER_CURRENT_VERSION}_linux_amd64.zip"
    ;;

  verify)
    ./packer --version
    jq ".\"post-processors\"[0] |= map(select(.\"type\" != \"vagrant-cloud\"))" vagrant.json | ./packer validate -var "iso_url=https://downloads.archlinux.de/iso/$(date +'%Y.%m').01/archlinux-$(date +'%Y.%m').01-x86_64.iso" -var "iso_checksum_url=https://downloads.archlinux.de/iso/$(date +'%Y.%m').01/sha1sums.txt" -
    ;;

  *)
    exit 1
    ;;
esac
