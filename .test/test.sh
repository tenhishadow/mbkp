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

# prep ssh for a test
if [[ -d ~/.ssh ]]; then
  echo ok
else
  mkdir ~/.ssh
  chmod 0700 ~/.ssh
fi
cp .test/.ssh_config ~/.ssh/config

# check chr is up and running
ssh chr_test \
  "system resource print"

# set test-values for backup to check after backup
## non-sensitive
ssh chr_test \
  "system identity set name=Kn4kk3ed5D4FuD3s7VeMmeecHMDhwgFaci54t7ETnFtARkQsi"
## sensitive
ssh chr_test \
  "ppp secret add name=test-backup-value password=oobddvSAqPtDNagrjdPEkK4vxfox7euM2kXRtaJFqZjQZ5T77"

## temp
ssh chr_test \
  "export"

# check that we run the same we launch(ну нет уже веры никому)
version_running=$(ssh \
  -F .test/.ssh_config chr_test \
    "system resource print" \
      | awk -F ':' \
      '/version/ {sub(/^ */, "", $2); split($2, a, " "); print a[1]}')

if [[ "$1" != "$version_running" ]]; then
  echo "something wrong in test"
  exit 1
else
  echo "Versions are the same."
fi


# do backup
bash -x mbkp.sh .test/test.cfg
