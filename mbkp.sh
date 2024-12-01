#!/bin/bash

# mikrotik-backup script
# author tenhi (adm@tenhi.dev)

# Default variables ( may be overrided in custom config )
#### Connection ####################################
IDL="5s"                                                # Default idle time
#### Backup variables ##############################
BKP_BINPWD="NvLB37zchdor9Y4E8KSpxibWHATfjstnw"          # Default password for binary backup    33cr
BKP_EXPPWD="hGAEJKptcCznB2v8RaHkoxiSTYNFZ3suW"          # Default password  for export          33cr
ST_RTN="30"                                             # Default retention time
#### Storage variables #############################
ST_ROOT="/mnt/bkp_share/mikrotik"                       # Default storage root
SC_USER=$(whoami)                                       # default user for using script(need to chown dir)
ST_MODE="755"

#######################################################################################################################
# import config
## check if it's avaliable
if [[ ( -z ${1} ) || ( ! -r ${1} ) ]]
then
  printf '%s\n' "ERR: cannot  read config file"
  exit 1
fi
# shellcheck source=example.cfg
source "${1}"
#######################################################################################################################

# Functions
#### Utils #############################################################################################
CMD_FIND=$(command -v find)
CMD_MV=$(command -v mv)
CMD_GZ=$(command -v gzip)
CMD_CHO=$(command -v chown)
CMD_CHM=$(command -v chmod)
CMD_MKD="$(command -v mkdir) -p "
CMD_RM=$(command -v rm)
CMD_DATE=$(date +%Y%m%d_%H%M) # date in format YYYYMMDD_HHmm
CMD_SSL=$(command -v openssl)
CMD_SSH=$(command -v ssh)
CMD_SCP=$(command -v scp)

ST_FULL="${ST_ROOT}/${TGT_HOSTNAME}/"      # full path to .backup (/root_storage/hostname/)
ST_ARCH="${ST_FULL}archive/"              # full path to archive (/root_storage/hostname/archive)
TGT_BKPNAME_BIN="${TGT_HOSTNAME}_${CMD_DATE}.backup"
TGT_BKPNAME_EXP="${TGT_HOSTNAME}_${CMD_DATE}.export"

#### Defining functions ################################################################################

function fn_check_log {
# Function for checking need of creating logfile
  LOG="${ST_ROOT}/LOG.txt"
  if [[ ! -r ${LOG} || -z ${LOG} ]]
   then
     printf '%s\n' \
       '#######' \
       "# logfile for ${0}" \
       '# The format is:' \
       '#       DATE;STATE;FILENAME;DEVICE_HOSTNAME;DEVICE_MODEL;DEVICE_REVISION;DEVICE_SERIAL' \
       '# author: tenhi(adm@tenhi.dev)' \
       '#######' '   ###' '    #' ' ' > $LOG
   fi
}

function fn_check_readme {
# Function for checking need of creating readme
  README="${ST_ROOT}/README.txt"
  if [[ ! -r $README || -z ${LOG} ]]
  then
    printf '%s\n' \
     '#######' \
     "# readme for ${0}" \
     '# backups located in:' \
     '#   hostname/..' \
     '# achives located in:' \
     '#   hostname/archive/...' \
     "# logs in ${LOG}" \
     '#######' '   ###' '    #' ' ' > ${README}
  fi
}

function fn_check_directory {
# Function for checking||creating full-path dirs
  if [[ ( ! -d "${ST_FULL}archive" ) || ( ! -r "${ST_FULL}archive" ) ]]
  then
    # create dirs
    if ! ${CMD_MKD} "${ST_FULL}archive"
    then
      printf '%s\n' "ERR: cannot create dir ${ST_FULL}archive"
      exit 1
    fi

    # chown it
    if ! ${CMD_CHO} "${SC_USER}" "${ST_FULL}"
    then
      printf '%s\n' "cannot chown ${ST_FULL} to ${SC_USER}"
      exit 1
    fi
    # chmod
    if ! ${CMD_CHM} ${ST_MODE} "${ST_FULL}"
    then
      printf '%s\n' "ERR: cannot chmod ${ST_MODE} for ${ST_FULL}"
      exit 1
    fi
  fi
}

function fn_mikrotik_cleanup {
  # cleanup before backup
  ${CMD_SSH} "${TGT_HOSTNAME}" "ip dns cache flush"
  ${CMD_SSH} "${TGT_HOSTNAME}" "console clear-history"
  # gather facts about device
  DEVICE_HOSTNAME=$( ${CMD_SSH} "${TGT_HOSTNAME}" ':put [ system identity get name ]' )
  DEVICE_MODEL=$( ${CMD_SSH} "${TGT_HOSTNAME}" ':put [ system routerboard get model ]' )
  DEVICE_REVISION=$( ${CMD_SSH} "${TGT_HOSTNAME}" ':put [ system routerboard get revision ]' )
  DEVICE_SERIAL=$( ${CMD_SSH} "${TGT_HOSTNAME}" ':put [ system routerboard get serial-number ]' )
}

function fn_backup_binary {
 # Function for saving binary backup
 T_BKPSTR="system backup save name=${TGT_BKPNAME_BIN} dont-encrypt=no password=${BKP_BINPWD}"
 T_BKPCLN="file remove [find name=${TGT_BKPNAME_BIN}]"

 # Put output result exec mikrotik command to /dev/null
 ${CMD_SSH} "${TGT_HOSTNAME}" "${T_BKPSTR}" > /dev/null        # Initializing backup

 sleep ${IDL} && ${CMD_SCP} "${TGT_HOSTNAME}":/"${TGT_BKPNAME_BIN}" "${ST_FULL}"  # Copy file to storage
 sleep ${IDL} && ${CMD_SSH} "${TGT_HOSTNAME}" "${T_BKPCLN}"                       # Remove created file on mikrotik
}

function fn_backup_export {
 # Function for saving exported config
 EXP_TMP_FILE="/tmp/${RANDOM}.export"

 # define export command depends on ros version
 _ros_version=$( sleep ${IDL} \
   && ${CMD_SSH} "${TGT_HOSTNAME}" \
     "system resource print" \
     | awk \
     -F ':' \
     '/version/ {sub(/^ */, "", $2); split($2, a, " "); split(a[1], b, "."); print b[1]}')
 case $_ros_version in
  "6")
   _export_command="export"
   ;;
  "7")
   _export_command="export show-sensitive"
   ;;
  "*")
   echo "non-supported version"
   exit 1
   ;;
 esac

 sleep ${IDL} && ${CMD_SSH} "${TGT_HOSTNAME}" "${_export_command}" > ${EXP_TMP_FILE}
 ${CMD_SSL} aes-256-cbc -salt -pbkdf2 -iter 100000 \
   -k ${BKP_EXPPWD} \
   -in ${EXP_TMP_FILE} \
   -out "${ST_FULL}${TGT_BKPNAME_EXP}.des3"
 ${CMD_RM} ${EXP_TMP_FILE}
}

function fn_backup_retention {
# Function for rotating old backups
  # Search old backups only one directory, not tree
  ${CMD_FIND} "${ST_FULL}" -maxdepth 1 -mtime +$ST_RTN -type f -exec "${CMD_MV}" {} "${ST_ARCH}" \;
  # Add into archive only not gz files
  ${CMD_FIND} "${ST_ARCH}" -not -name "*.gz" -type f -exec "${CMD_GZ}" {} \;
}

function fn_log {
# Function for recording results to logfile

  # log about binary backup
  if [[ -r ${ST_FULL}${TGT_BKPNAME_BIN} ]]
  then
    printf '%s\n' "${CMD_DATE};okay;${TGT_BKPNAME_BIN};${DEVICE_HOSTNAME};${DEVICE_MODEL};${DEVICE_REVISION};${DEVICE_SERIAL}" >> $LOG
  else
    printf '%s\n' "${CMD_DATE};fail;${TGT_BKPNAME_BIN};${DEVICE_HOSTNAME};${DEVICE_MODEL};${DEVICE_REVISION};${DEVICE_SERIAL}" >> $LOG
  fi

  # log about text backup
  if [[ -r ${ST_FULL}${TGT_BKPNAME_EXP}".des3" ]]
  then
    printf '%s\n' "${CMD_DATE};okay;${TGT_BKPNAME_EXP}.des3;${DEVICE_HOSTNAME};${DEVICE_MODEL};${DEVICE_REVISION};${DEVICE_SERIAL}" >> $LOG
  else
    printf '%s\n' "${CMD_DATE};fail;${TGT_BKPNAME_EXP}.des3;${DEVICE_HOSTNAME};${DEVICE_MODEL};${DEVICE_REVISION};${DEVICE_SERIAL}" >> $LOG
  fi
}

##
# Start Execution
##

fn_check_directory                      # Checking and creating dirs
fn_check_log                            # Checking need of creating log-file
fn_check_readme                         # Checking need of creating readme
fn_backup_retention                     # Handling old backups

# init cleanup and check ssh connection
if ! fn_mikrotik_cleanup
then
  fn_log
  printf '%s\n' "ERR: cannot establish ssh-connection"
  exit 1
fi

sleep ${IDL} && fn_backup_binary        # save binary backup
sleep ${IDL} && fn_backup_export        # save exported config
sleep ${IDL} && fn_mikrotik_cleanup     # Clean it again to hide commands

fn_log                                  # Recording backup results to file
