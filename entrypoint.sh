#!/bin/sh

PUID=${PUID:-500}
GUID=${GUID:-500}
usermod --uid ${PUID} ums
groupmod --gid ${GUID} ums
UMASK_SET=${UMASK_SET:-022}
umask "$UMASK_SET"

# function to provide some standard output
console_output() {
  echo "${1}  $(date +"%H:%M:%S.%3N") [entrypoint] ${2}"
}

# function to set custom parameters in UMS.conf
set_ums_parameter() {
  console_output INFO "Setting UMS setting '${1}' to '${2}'"
  sed -i "s+^${1} =$+${1} = ${2}+g" /opt/ums/UMS.conf
}

# check to see if the FOLDER env var has been passed
if [ -n "${FOLDER}" ]
then
  # append the FOLDER variable data in the UMS.conf
  set_ums_parameter folders "${FOLDER}"

  # check to see if we should set the permissions for the FOLDER
  if [ "${SET_MEDIA_PERMISSIONS}" = "true" ]
  then
    console_output INFO "SET_MEDIA_PERMISSIONS=true; setting 'o+rx' on '${FOLDER}'"
    chmod -R o+rx "${FOLDER}"
  fi
fi

# check to see if the LOG_LEVEL env var has been passed
if [ -n "${LOG_LEVEL}" ]
then
  # append the LOG_LEVEL variable in the UMS.conf
  set_ums_parameter log_level "${LOG_LEVEL}"
  set_ums_parameter logging_filter_console "${LOG_LEVEL}"
fi

# check to see if the NETWORK_INTERFACE env var has been passed
if [ -n "${NETWORK_INTERFACE}" ]
then
  # append the NETWORK_INTERFACE variable in the UMS.conf
  set_ums_parameter network_interface "${NETWORK_INTERFACE}"
fi

# check to see if the PORT env var has been passed
if [ -n "${PORT}" ]
then
  # append the PORT variable in the UMS.conf
  set_ums_parameter port "${PORT}"
fi

# make sure ownership is set appropriately on each file/directory
for FILEorDIR in UMS.conf UMS.cred data database
do
  # make sure the file or directory exists before performing permission check; skip if it doesn't exists
  if [ -e "/opt/ums/${FILEorDIR}" ]
  then
    # get the owner and group
    OWNER="$(stat -c '%u' /opt/ums/${FILEorDIR})"
    GROUP="$(stat -c '%g' /opt/ums/${FILEorDIR})"

    # check to see if permissions are incorrect or FORCE_CHOWN=true
    if [ "${OWNER}" != "${PUID}" ] || [ "${GROUP}" != "${PGID}" ] || [ "${FORCE_CHOWN}" = "true" ]
    then
      # special output if FORCE_CHOWN=true
      if [ "${FORCE_CHOWN}" = "true" ]
      then
        # FORCE_CHOWN=true
        console_output INFO "FORCE_CHOWN=true; setting ownership on '/opt/ums/${FILEorDIR}' to (${PUID}:${PGID})"
      else
        # permissions are just incorrect; notify user that uid:gid are not correct and fix them
        console_output WARN "ownership not correct on '/opt/ums/${FILEorDIR}' (${OWNER}:${GROUP}); setting correct ownership (${PUID}:${PGID})"
      fi

      # change ownership
      chown -R ${PUID}:${PGID} "/opt/ums/${FILEorDIR}"
    else
      console_output INFO "ownership is correct on '/opt/ums/${FILEorDIR}'"
    fi

    # set permissions on directories that don't have the right permissions
    find "/opt/ums/${FILEorDIR}" -type d ! -perm -750 -exec chmod -v 750 {} \;

    # set permissions on files
    find "/opt/ums/${FILEorDIR}" -type f ! -perm -640 -exec chmod -v 640 {} \;
  fi
done


# hack: add /opt/ums/linux to path
console_output INFO "Adding '/opt/ums/linux' to the PATH"
export PATH="$PATH:/opt/ums/linux"

# output message about ending entrypoint
console_output INFO "Launching command '${*}' as user ums"
exec gosu ums "${@}"
