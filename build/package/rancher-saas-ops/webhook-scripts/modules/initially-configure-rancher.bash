#!/bin/bash

## Import other scripts
# logging.bash for functions logToStderr, logToStdout and webhookResponse
source /opt/webhook-scripts/modules/logging.bash

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

## Define variables
CONFIG_STAGE="configuration"

## Define functions
cleanup () {
  unset LOGINRESPONSE
  unset LOGINTOKEN
  unset USERID
}

## Check needed arguments
if [ "$#" -ne 4 ]; then
  ENV_CHECK="error"
  logToStderr $CONFIG_STAGE "Not the correct amount of arguments passed, expected 4"
  logToStderr $CONFIG_STAGE "Pass the following arguments: instance-name, password, job-id, initial starttime"
fi

## Check ENV_CHECK before proceede wiht actual script
if [ "$ENV_CHECK" == "error" ]; then
  logToStderr $CONFIG_STAGE "Configuration not correct"
  exit 1
fi

## The actual script
# Start the health check script
logToStdout $CONFIG_STAGE "INFO" "Start health check script"
/opt/webhook-scripts/modules/check-rancher-health.bash $INSTANCE_NAME $JOB_ID $INITIALSTARTTIME
# Check if health check script was successful
if (( $? != "0" )); then
  logToStderr $CONFIG_STAGE "Health check script for $INSTANCE_NAME was not successful"
  cleanup
  exit 1
else
  logToStdout $CONFIG_STAGE "INFO" "Health check script for $INSTANCE_NAME was successful"
fi

# Get Rancher login token
logToStdout $CONFIG_STAGE "INFO" "Get Rancher login token"
LOGINRESPONSE="undefined"
LOGINTOKEN="undefined"
USERID="undefined"
LOGINRESPONSE=`curl -s "https://$INSTANCE_NAME.$DOMAIN/v3-public/localProviders/local?action=login" \
  -H 'content-type: application/json' \
  --data-binary '{"username":"admin","password":"admin"}' \
  --insecure`
# Check if Rancher login was successful
if (( $? != "0" )); then
  logToStderr $CONFIG_STAGE "Rancher login did not complete successully"
  cleanup
  exit 1
else
  logToStdout $CONFIG_STAGE "INFO" "Rancher login was successful"
fi
    
LOGINTOKEN=`echo $LOGINRESPONSE | jq -r .token`
USERID=`echo $LOGINRESPONSE | jq -r .userId`

# Set Rancher admin password
logToStdout $CONFIG_STAGE "INFO" "Set Rancher admin password"
curl -s "https://$INSTANCE_NAME.$DOMAIN/v3/users?action=changepassword" \
  -H 'content-type: application/json' \
  -H "Authorization: Bearer $LOGINTOKEN" \
  --data-binary '{"currentPassword":"admin","newPassword":"'$ADMIN_PW'"}' \
  --insecure
# Check if Rancher admin passwort setting was successful
if (( $? != "0" )); then
  logToStderr $CONFIG_STAGE "Set Rancher admin password did not complete successully"
  cleanup
  exit 1
else
  logToStdout $CONFIG_STAGE "INFO" "Set Rancher admin password was successful"
fi

# Force Rancher admin to change password on first login
logToStdout $CONFIG_STAGE "INFO" "Force Rancher admin to change password on first login"
curl -X PUT -s "https://$INSTANCE_NAME.$DOMAIN/v3/users/$USERID" \
  -H 'content-type: application/json' \
  -H "Authorization: Bearer $LOGINTOKEN" \
  --data-binary '{"mustChangePassword": true}' \
  --insecure >> /dev/null
# Check if forcing Rancher admin to change password on first login was successful
if (( $? != "0" )); then
  logToStderr $CONFIG_STAGE "Force Rancher admin to change password on first login not successful"
  cleanup
  exit 1
else
  logToStdout $CONFIG_STAGE "INFO" "Force Rancher admin to change password on first login was successful"
fi

# Set Rancher URL
logToStdout $CONFIG_STAGE "INFO" "Set Rancher URL"
curl -s "https://$INSTANCE_NAME.$DOMAIN/v3/settings/server-url" \
  -H 'content-type: application/json' \
  -H "Authorization: Bearer $LOGINTOKEN" \
  -X PUT \
  --data-binary '{"name":"server-url","value":"'$INSTANCE_NAME.$DOMAIN'"}' \
  --insecure >> /dev/null
# Check if Rancher URL setting was successful
if (( $? != "0" )); then
  logToStderr $CONFIG_STAGE "Set Rancher URL did not complete successully"
  cleanup
  exit 1
else
  logToStdout $CONFIG_STAGE "INFO" "Set Rancher URL was successful"
fi
logToStdout $CONFIG_STAGE "INFO" "Finished Rancher $INSTANCE_NAME deployment successfully"

cleanup
unset CONFIG_STAGE
exit 0