#!/bin/bash

# mikrotik-backup script
# author Tenhi

# Initial checks
# Config file should be provided and should be readable
[[ -z "$1" ]] && echo "ERR: no config file provided" && exit 1
! [[ -r "$1" ]] && echo "ERR: cannot  read $1" && exit 1

# Default variables ( may be overrided in custom config )
#### Connection ####################################
TGT_PORT="22"                                           # default ssh-port
TGT_USER="bkpuser"                                      # Default backup user
IDL="5s"                                                # Default idle time
#### Backup variables ##############################
BKP_BINPWD="NvLB37zchdor9Y4E8KSpxibWHATfjstnw"          # Default password for binary backup    33cr
BKP_EXPPWD="hGAEJKptcCznB2v8RaHkoxiSTYNFZ3suW"          # Default password  for export          33cr
ST_RTN="30"                                             # Default retention time
#### Storage variables #############################
ST_ROOT="/mnt/bkp_share/mikrotik"                       # Default storage root
SC_USER="root"		# default user for using script(need to chown dir)
SC_GROUP="root"		# default group

#######################################################################################################################
# Importing target config where you can override options
source $1
#######################################################################################################################

# Functions
#### Utils #############################################################################################
CMD_FIND=$(which find)
CMD_MV=$(which mv)
CMD_GZ=$(which gzip)
CMD_CHO=$(which chown)
CMD_CHM=$(which chmod)
CMD_MKD=$(which mkdir)" -p "
CMD_RM=$(which rm)
CMD_DATE=$(date +%Y%m%d_%H%M) # date in format YYYYMMDD_HHmm
CMD_SSL=$(which openssl)
CMD_SSH=$(which ssh)
CMD_SCP=$(which scp)

########################################################################################################
ST_FULL=$ST_ROOT/$ST_HOSTNAME"/"        # full path to .backup (/root_storage/hostname/)
ST_ARCH=$ST_FULL"archive/"              # full path to archive (/root_storage/hostname/archive)
TGT_BKPNAME_BIN=$ST_HOSTNAME"_"$CMD_DATE".backup"
TGT_BKPNAME_EXP=$ST_HOSTNAME"_"$CMD_DATE".export"

SSH_OPT=" -o ConnectionAttempts=5 -o ConnectTimeout=5s \
-o PasswordAuthentication=no -o PreferredAuthentications=publickey \
-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
-o GlobalKnownHostsFile=/dev/null -o CheckHostIP=no "
SSH_STR="$CMD_SSH -2 -4 -p $TGT_PORT -l $TGT_USER $TGT_IP $SSH_OPT"
SCP_STR="$CMD_SCP -2 -4 -B $SSH_OPT -P $TGT_PORT $TGT_USER@$TGT_IP:/$TGT_BKPNAME_BIN $ST_FULL"

#\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\\
#### Defining functions ################################################################################

function fn_check_log {
# Function for checking need of creating logfile
LOG=$ST_ROOT/"LOG.txt"                                  # log-file location


 if [[ -r $LOG ]]
  then
   return 0
  else
   echo "
################################################
# Logfile for mikrotik backups
# The format is:
#       DATE;STATE;FILENAME
# author: Tenhi(adm@tenhi.ru)
################################################

" > $LOG
 fi
}
function fn_check_readme {
# Function for checking need of creating readme

README=$ST_ROOT"/README.txt"      # README File

 if [[ -r $README ]]
  then
   return 0
  else
   echo "
# ===
# Here you can find backups for all Mikrotiks
# Files located in:
#       hostname/...
# Archived backups are in:
#       hostname/archive/...
# You can get backup info for all jobs in LOG.txt
# ===
" > $README
 fi
}
function fn_check_directory {
# Function for checking||creating full-path dirs

 if [[ -d $ST_FULL"archive" && -r $ST_FULL"archive" ]]
  then
   return 0
  else
   $CMD_MKD $ST_FULL"archive"
   $CMD_CHO $SC_USER:$SC_GROUP $ST_FULL
   $CMD_CHM 755 $ST_FULL
 fi
}

function fn_mikrotik_cleanup {
# Function for cleaning up target mikrotik

$SSH_STR "ip dns cache flush"
$SSH_STR "console clear-history"
}
function fn_mikrotik_fixtime {
# Function for setting ntp client

$SSH_STR "ip cloud set update-time=no; system ntp client set primary-ntp=0.0.0.0 secondary-ntp=0.0.0.0 enabled=yes server-dns-names=pool.ntp.org"
}

function fn_backup_binary {
 # Function for saving binary backup
 # Changed 20170901
 T_BKPSTR="system backup save name=$TGT_BKPNAME_BIN dont-encrypt=no password=$BKP_BINPWD"
 T_BKPCLN="file remove [find name=$TGT_BKPNAME_BIN]"


 # Put output result exec mikrotik command to /dev/null
 $SSH_STR $T_BKPSTR > /dev/null          # Initializing backup

 sleep $IDL && $SCP_STR                  # Copy file to storage
 sleep $IDL && $SSH_STR $T_BKPCLN        # Remove created file on mikrotik
}
function fn_backup_export {
 # Function for saving exported config

 # NOTE: decrypt the file
 # openssl des3 -d -salt -in encryptedfile.txt -out normalfile.txt
 EXP_TMP_FILE="/tmp/"$RANDOM".export"

 sleep $IDL && $SSH_STR export > $EXP_TMP_FILE
 $CMD_SSL des3 -salt -k $BKP_EXPPWD -in $EXP_TMP_FILE -out $ST_FULL$TGT_BKPNAME_EXP".des3"
 $CMD_RM $EXP_TMP_FILE

}

function fn_backup_retention {
# Function for rotating old backups

 # Search old backups only one directory, not tree
  $CMD_FIND $ST_FULL -maxdepth 1 -mtime +$ST_RTN -type f -exec $CMD_MV {} $ST_ARCH \;
 # Add into archive only not gz files
  $CMD_FIND $ST_ARCH -not -name "*.gz" -type f -exec $CMD_GZ {} \;
}

function fn_log {
# Function for recording results to logfile

 if [[ -r $ST_FULL$TGT_BKPNAME_BIN ]]
  then
   echo $CMD_DATE";okay;"$TGT_BKPNAME_BIN >> $LOG
  else
   echo $CMD_DATE";fail;"$TGT_BKPNAME_BIN >> $LOG
 fi

 if [[ -r $ST_FULL$TGT_BKPNAME_EXP".des3" ]]
  then
   echo $CMD_DATE";okay;"$TGT_BKPNAME_EXP".des3" >> $LOG
  else
   echo $CMD_DATE";fail;"$TGT_BKPNAME_EXP".des3" >> $LOG
 fi

}

##
# Start Execution
##

fn_check_directory                      # Checking and creating dirs

fn_check_log                            # Checking need of creating log-file
fn_check_readme                         # Checking need of creating readme

fn_backup_retention                     # Handling old backups
fn_mikrotik_cleanup                     # Initial cleanup
[[ $? -ne 0 ]] && fn_log && echo "ERR: cannot establish ssh-connection" && exit 1

sleep $IDL && fn_backup_binary           # save binary backup
sleep $IDL && fn_backup_export           # save exported config
sleep $IDL && fn_mikrotik_fixtime
sleep $IDL && fn_mikrotik_cleanup        # Clean it again to hide commands
fn_log                                   # Recording backup results to file
