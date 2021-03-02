#!/bin/bash

## Expected environment variables
# DOMAIN

## Expected arguments
# $1: Rancher SaaS instance name, like: rancher-saas-dev
# $2: Rancher SaaS admin password
# $3: Job ID, integer
# $4: initial starttime, integer

## Save passed arguments
readonly INSTANCE_NAME="$1"
readonly ADMIN_PW="$2"
readonly JOB_ID="$3"
readonly INITIALSTARTTIME="$4"

## Define varialbes for log output
if [ "$LOCAL" == "true" ]
  then
    OKLOGTARGET="/dev/stdout"
    ERRORLOGTARGET="/dev/stderr"
  else
    OKLOGTARGET="/proc/1/fd/1"
    ERRORLOGTARGET="/proc/1/fd/2"
fi

## Define global variable
STATUS="undefined"

## Define functions
setduration () {
  local ENDTIME=$(date +%s%3N)
  DURATION=$(echo "$ENDTIME - $INITIALSTARTTIME" | bc -l)
}

errorlog () {
  local MESSAGE="$1"
  if [ -z "$JOB_ID" ]; then
    echo 'time="'$(date +%d-%m-%Y\ %H:%M:%S)'" jobID=0 level=error stage=configure message="'$MESSAGE'"' > $ERRORLOGTARGET
  else
    echo 'time="'$(date +%d-%m-%Y\ %H:%M:%S)'" jobID="'$JOB_ID'" level=error stage=configure message="'$MESSAGE'"' > $ERRORLOGTARGET
  fi
}

oklog () {
  local LEVEL="$1"
  local MESSAGE="$2"
  if [ -z "$JOB_ID" ]; then
    echo 'time="'$(date +%d-%m-%Y\ %H:%M:%S)'" jobID=0 level="'$LEVEL'" stage=configure message="'$MESSAGE'"' > $OKLOGTARGET
  else
    echo 'time="'$(date +%d-%m-%Y\ %H:%M:%S)'" jobID="'$JOB_ID'" level="'$LEVEL'" stage=configure message="'$MESSAGE'"' > $OKLOGTARGET
  fi
}

cleanup () {
  unset LOGINRESPONSE
  unset LOGINTOKEN
  unset USERID
}

if [[ ! -v DOMAIN ]]
  then
    STATUS="error"
    errorlog "Environment variable DOMAIN not set"
fi

## Check needed arguments
if [ "$#" -ne 4 ]; then
  STATUS="error"
  errorlog "Not the correct amount of arguments passed, expected 4"
  errorlog "Pass the following arguments: instance-name, password, job-id, initial starttime"
fi

## Check status before proceede wiht actual script
if [ "$STATUS" == "error" ]; then
  STATUS="error"
  setduration
  errorlog "Something with the configuration is wrong, duration $DURATION ms"
  returnlog "Configuration not correct"
  exit 1
fi

## The actual script
# Start the health check script
oklog "INFO" "Start health check script"
/opt/webhook-scripts/check-rancher-health.bash $INSTANCE_NAME $JOB_ID $INITIALSTARTTIME
# Check if health check script was successful
if (( $? != "0" )); then
  STATUS="error"
  setduration
  errorlog "Health check script for $INSTANCE_NAME was not successful, duration $DURATION ms"
  cleanup
  exit 1
else
  oklog "OK" "Health check script for $INSTANCE_NAME was successful"
fi

# Get Rancher login token
oklog "INFO" "Get Rancher login token"
LOGINRESPONSE="undefined"
LOGINTOKEN="undefined"
USERID="undefined"
LOGINRESPONSE=`curl -s "https://$INSTANCE_NAME.$DOMAIN/v3-public/localProviders/local?action=login" \
  -H 'content-type: application/json' \
  --data-binary '{"username":"admin","password":"admin"}' \
  --insecure`
# Check if Rancher login was successful
if (( $? != "0" )); then
  STATUS="error"
  setduration
  errorlog "Rancher login did not complete successully, duration $DURATION ms"
  cleanup
  exit 1
else
  oklog "OK" "Rancher login was successful"
fi
    
LOGINTOKEN=`echo $LOGINRESPONSE | jq -r .token`
USERID=`echo $LOGINRESPONSE | jq -r .userId`
#oklog "DEBUG" "Rancher login token: $LOGINTOKEN"
#oklog "DEBUG" "Rancher admin userId: $USERID"

# Set Rancher admin password
oklog "INFO" "Set Rancher admin password"
curl -s "https://$INSTANCE_NAME.$DOMAIN/v3/users?action=changepassword" \
  -H 'content-type: application/json' \
  -H "Authorization: Bearer $LOGINTOKEN" \
  --data-binary '{"currentPassword":"admin","newPassword":"'$ADMIN_PW'"}' \
  --insecure
# Check if Rancher admin passwort setting was successful
if (( $? != "0" )); then
  STATUS="error"
  setduration
  errorlog "Set Rancher admin password did not complete successully, duration $DURATION ms"
  cleanup
  exit 1
else
  oklog "OK" "Set Rancher admin password was successful"
fi

# Force Rancher admin to change password on first login
oklog "INFO" "Force Rancher admin to change password on first login"
curl -X PUT -s "https://$INSTANCE_NAME.$DOMAIN/v3/users/$USERID" \
  -H 'content-type: application/json' \
  -H "Authorization: Bearer $LOGINTOKEN" \
  --data-binary '{"mustChangePassword": true}' \
  --insecure >> /dev/null
# Check if forcing Rancher admin to change password on first login was successful
if (( $? != "0" )); then
  STATUS="error"
  setduration
  errorlog "Force Rancher admin to change password on first login not successful, duration $DURATION ms"
  cleanup
  exit 1
else
  oklog "OK" "Force Rancher admin to change password on first login was successful"
fi

# Set Rancher URL
oklog "INFO" "Set Rancher URL"
curl -s "https://$INSTANCE_NAME.$DOMAIN/v3/settings/server-url" \
  -H 'content-type: application/json' \
  -H "Authorization: Bearer $LOGINTOKEN" \
  -X PUT \
  --data-binary '{"name":"server-url","value":"'$INSTANCE_NAME.$DOMAIN'"}' \
  --insecure >> /dev/null
# Check if Rancher URL setting was successful
if (( $? != "0" )); then
  STATUS="error"
  setduration
  errorlog "Set Rancher URL did not complete successully, duration $DURATION ms"
  cleanup
  exit 1
else
  oklog "OK" "Set Rancher URL was successful"
fi
STATUS="ok"
setduration
oklog "OK" "Finished Rancher $INSTANCE_NAME deployment successfully, duration $DURATION ms"
cleanup
exit 0