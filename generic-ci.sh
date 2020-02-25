#!/bin/bash
set -x

case $1 in

  install-packer)
    PACKER_CURRENT_VERSION="$(curl -s https://checkpoint-api.hashicorp.com/v1/check/packer | jq -r -M '.current_version')"
    PACKER_URL="https://releases.hashicorp.com/packer/$PACKER_CURRENT_VERSION/packer_${PACKER_CURRENT_VERSION}_linux_amd64.zip"
    PACKER_SHA256="https://releases.hashicorp.com/packer/$PACKER_CURRENT_VERSION/packer_${PACKER_CURRENT_VERSION}_SHA256SUMS"
    PACKER_SHA256_SIG="https://releases.hashicorp.com/packer/$PACKER_CURRENT_VERSION/packer_${PACKER_CURRENT_VERSION}_SHA256SUMS.sig"
    HASHICORP_FINGERPRINT=91a6e7f85d05c65630bef18951852d87348ffc4c
    HASHICORP_KEY="https://keybase.io/hashicorp/pgp_keys.asc?fingerprint=${HASHICORP_FINGERPRINT}"
    curl -LO "${PACKER_URL}"
    curl -LO "${PACKER_SHA256}"
    curl -LO "${PACKER_SHA256_SIG}"
    wget -Lo hashicorp.key "${HASHICORP_KEY}"
    gpg --with-fingerprint --with-colons hashicorp.key | grep ${HASHICORP_FINGERPRINT^^}
    gpg --import hashicorp.key
    gpg --verify "packer_${PACKER_CURRENT_VERSION}_SHA256SUMS.sig" "packer_${PACKER_CURRENT_VERSION}_SHA256SUMS"
    grep linux_amd64 "packer_${PACKER_CURRENT_VERSION}_SHA256SUMS" >packer_SHA256SUM_linux_amd64
    sha256sum --check --status packer_SHA256SUM_linux_amd64
    unzip "packer_${PACKER_CURRENT_VERSION}_linux_amd64.zip"
    ./packer --version
    ;;

  install-shfmt)
    SHFMT_VERSION="$(curl -s https://api.github.com/repos/mvdan/sh/releases/latest | jq -r -M '.tag_name')"
    curl -Lo shfmt https://github.com/mvdan/sh/releases/download/"${SHFMT_VERSION}"/shfmt_"${SHFMT_VERSION}"_linux_amd64
    chmod +x ./shfmt
    ./shfmt --version
    ;;

  install-yapf)
    pip3 install yapf --user
    ;;

  install-flake8)
    pip3 install flake8 --user
    ;;

  verify-official)
    ./packer validate -var "iso_checksum_url=https://mirror.pkgbuild.com/iso/latest/sha1sums.txt" -except=vagrant-cloud vagrant.json
    ;;

  verify-local)
    ./packer validate local.json
    ;;

  # We use + instead of \; here because find doesn't pass
  # the exit code through when used with \;
  shellcheck)
    find . -iname "*.sh" -exec shellcheck {} +
    ;;

  shfmt)
    find . -iname "*.sh" -exec ./shfmt -i 2 -ci -d {} +
    ;;

  yapf)
    find . -iname "*.py" -exec python3 -m yapf -d {} +
    ;;

  flake8)
    find . -iname "*.py" -exec python3 -m flake8 {} +
    ;;

  *)
    exit 1
    ;;
esac
