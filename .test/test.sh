#!/bin/bash

set -o nounset
set -o noclobber
set -o errexit
set -o pipefail

# deps | get chr disk image
wget -qO- \
  "https://download.mikrotik.com/routeros/${1}/chr-${1}.img.zip" \
  | zcat \
  > "chr-${1}.img"

# run vm
qemu-system-x86_64 \
  -daemonize \
  -display none \
  -m 256 \
  -net nic,model=virtio \
  -net user,hostfwd=tcp::2345-:22 \
  -drive file="chr-${1}.img",format=raw,if=ide

# check chr is up and running
ssh -F .test/.ssh_config chr_test \
  "system resource print"

# check that we run the same we launch(ну нет уже веры никому)
version_running=$(
ssh -F .test/.ssh_config chr_test \
  "system resource print" \
  | awk -F ':' \
  '/version/ {sub(/^ */, "", $2); print $2}' \
  | awk '{print $1}' )

echo "DBG: version running $version_running"
echo "DBG: version expected $1"

[[ "${1}" != "${version_running}" ]] && \
  echo "something wrong in test" && \
  exit 1
