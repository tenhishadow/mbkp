# mbkp
Mikrotik backup script

This script can be used to centralize the backup configurations of Mikrotik devices.
Each device has its own configuration file in which it can override the standard options.

# А теперь по-русски:
https://habr.com/post/342060/


# Scheduling
Here is crontab example:
```
# VARS:
MCFG="/etc/mikrotik_backup"
MBKP="/usr/local/bin/mbkp"
MLOG="/var/log/mikrotik_backup/log"
# TASKS:
00 03 * * *     $MBKP $MCFG"/somehost.cfg" >>$MLOG 2>>$MLOG             # Comment
```

# Recommended paths:

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
