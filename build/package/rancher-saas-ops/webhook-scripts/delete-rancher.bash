#!/bin/bash

## Comments
# We use exit 0 also for failues, with exti 1 the webhook does not reply with out custom error message 

export STARTTIME=$(date +%s%3N)

## Import other scripts
# logging.bash for functions logToStderr, logToStdout and webhookResponse
source /opt/webhook-scripts/modules/logging.bash

## Expected arguments
# $1: Object ID: integer
# $2: Rancher SaaS instance name, like: rancher-saas-dev
# $3: Job ID, integer

## Save passed arguments
export readonly OBJECT_ID="$1"
readonly INSTANCE_NAME="$2"
export readonly JOB_ID="$3"

## Define global variables
DELETE_PREFLIGHT_CHECK="undefined"
DELETE_STAGE="delete"

# Start logging
logToStdout $DELETE_STAGE "INFO" "START Rancher $INSTANCE_NAME deletion"

## Check needed arguments
if [ "$#" -ne 3 ]; then
  DELETE_PREFLIGHT_CHECK="error"
  logToStderr $DELETE_STAGE "Not the correct amount of arguments passed, expected 2"
  logToStderr $DELETE_STAGE "Pass the following arguments: object-id, instance-name, job-id"
fi

## Check kube-api connection
kubectl get namespaces > /dev/null 2>&1
if (( $? != "0" ))
  then
    DELETE_PREFLIGHT_CHECK="error"
    logToStderr $DELETE_STAGE "Not able to connect to kube-api"
fi

## Check DELETE_PREFLIGHT_CHECK before proceede wiht actual script
if [ "$DELETE_PREFLIGHT_CHECK" == "error" ]; then
  logToStderr $DELETE_STAGE "Configuration not correct"
  webhookResponse "error" "Configuration not correct"
  exit 0
fi

## The actual script
# Start the script for the initial rancher configuration and send it to the background
logToStdout $DELETE_STAGE "INFO" "Start health check script"
tmux new -d /opt/webhook-scripts/modules/delete-rancher-namespace.bash $OBJECT_ID $INSTANCE_NAME $JOB_ID $STARTTIME

webhookResponse "deleting" "Successfully sent delete command for $INSTANCE_NAME"
unset DELETE_STAGE
exit 0