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

# establish test values for backup to verify their existence following the backup process
TEST_VALUE_NSENSITIVE="Kn4kk3ed5D4FuD3s7VeMmeecHMDhwgFaci54t7ETnFtARkQsi"
TEST_VALUE_SENSITIVE="oobddvSAqPtDNagrjdPEkK4vxfox7euM2kXRtaJFqZjQZ5T77"
## non-sensitive
# shellcheck disable=SC2029
ssh chr_test \
  "system identity set name=$TEST_VALUE_NSENSITIVE"
## sensitive
# shellcheck disable=SC2029
ssh chr_test \
  "ppp secret add name=test-backup-value password=$TEST_VALUE_SENSITIVE"

## temp
echo "CHECKIT"
ssh chr_test \
  "export" | grep --quiet $TEST_VALUE_NSENSITIVE

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

# check backup
# shellcheck source=test.cfg
source .test/test.cfg

# check backup log for any fail
if [[ -r $LOG ]]; then
  if grep -i 'fail' $LOG; then
    echo "test: 'fail' record found in log file"
    exit 1
  else
    [[ $( grep -c "okay" $LOG ) == "2" ]] \
      && echo "test: both backups are okay in $LOG"
  fi
else
  echo "test: log file does not exist"
  exit 1
fi

# check decrypt process
openssl \
  des3 \
  -d \
  -salt \
  -k "${BKP_EXPPWD}" \
  -in "${ST_ROOT}/${TGT_HOSTNAME}/*.export.des3" \
  -out "${ST_ROOT}/${TGT_HOSTNAME}/.decrypted"

# check expected test-values in export

# [[ -r 29e7738e-6f65-4991-998c-be1cc916803f/chr_test/chr_test_20230326_2043.backup ]]
# [[ -r 29e7738e-6f65-4991-998c-be1cc916803f/chr_test/chr_test_20230326_2043.export.des3 ]]

# TGT_HOSTNAME="chr_test"
# BKP_BINPWD="YUUM3y7th2fAfCumiArzrJrKETU5nMQLNjAbrKZbVsDodbkhfqJit39udRd94pRhR"
# BKP_EXPPWD="rHap3Ahj99s44L2NFeZjZexAawLhhmF4MeNYe97dk5xAoPoMXeU3av9jqztpDZUKD"
