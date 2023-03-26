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

# GithubRunner | dir prep
# shellcheck source=test.cfg
source .test/test.cfg
mkdir -p "$ST_ROOT"
sudo chown "$USER:$GROUP" "$ST_ROOT"

# do backup
bash -x mbkp.sh .test/test.cfg
