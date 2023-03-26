# mbkp
Mikrotik backup script

![GitHub](https://img.shields.io/github/license/tenhishadow/mbkp?style=flat-square)
[![shellcheck](https://github.com/tenhishadow/mbkp/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/tenhishadow/mbkp/actions/workflows/shellcheck.yml)
[![test](https://github.com/tenhishadow/mbkp/actions/workflows/test.yml/badge.svg)](https://github.com/tenhishadow/mbkp/actions/workflows/test.yml)

This script can be used to centralize the backup configurations of Mikrotik devices.
Each device has its own configuration file in which it can override the standard options.

## А теперь по-русски:
https://habr.com/post/342060/

## Configuration
1. Read ```example.cfg```
2. Configure your devices using ssh_config files ( read ```man ssh_config``` )
### example config for host( for those who don't want to read documentation )
```bash
# file ~/.ssh/config
host *
  ControlMaster          auto # use just one connection for script
  ControlPath            ~/.ssh/control-%h-%p-%r
  ControlPersist         5m
  ForwardX11             no # disable useless
  IdentityFile           ~/.ssh/id_rsa # define default key if needed
  PasswordAuthentication no # disable useless
  Port                   22 # default port
  StrictHostKeyChecking  no # dont check hostkey
  User                   backupusr # default backup user

# gw jump
host mikrotik1
  Hostname 1.1.1.1

# ap
host mikrotik-ap1
  Hostname 192.168.88.2
  ProxyJump mikrotik1 # use gw as an entrypoint
  IdentityFile ~/.ssh/mykey # override if needed
  User xxx # override if needed
```
To make ProxyJump work you need to allow ssh forwarding on your mikrotik device via
```
> /ip ssh set forwarding-enabled=both
```

## Scheduling
Here is crontab example:
```
# VARS:
MCFG="/etc/mikrotik_backup"
MBKP="/usr/local/bin/mbkp"
MLOG="/var/log/mikrotik_backup/log"
# TASKS:
00 03 * * *     $MBKP $MCFG"/somehost.cfg" >>$MLOG 2>>$MLOG             # Comment
```

## Recommended paths:

- /etc/mikrotik_backup		directory where configuration files located

- /usr/local/bin/mbkp		executable bash script with default variables

- /var/log/mikrotik_backup/log	logfile to trace script execution results

This script does two backups (binary and export). Binary backup is protected with password
default password is included in executable script and it can be overrieded via custom config
file. Export is also password-protected but via openssl. Script export config to the temp file
as a plain text via ssh, then it encrypt this file and move it to the destination.
Encrypted exported config can be easly decrypted with openssl command:
```
 # NOTE: decrypt the file
 # openssl des3 -d -salt -in encryptedfile.txt -out normalfile.txt
```
