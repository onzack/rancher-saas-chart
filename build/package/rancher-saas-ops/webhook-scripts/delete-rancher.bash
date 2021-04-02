#!/bin/bash

## Comments
# We use exit 0 also for failues, with exti 1 the webhook does not reply with out custom error message 

export STARTTIME=$(date +%s%3N)

## Import other scripts
# logging.bash for functions logToStderr, logToStdout and webhookResponse
source /opt/webhook-scripts/modules/logging.bash

## Expected arguments
# $1: Rancher SaaS instance name, like: rancher-saas-dev
# $2: Job ID, integer

## Save passed arguments
readonly INSTANCE_NAME="$1"
export readonly JOB_ID="$2"

## Define global variables
DELETE_PREFLIGHT_CHECK="undefined"
DELETE_STAGE="delete"

# Start logging
logToStdout $DELETE_STAGE "INFO" "START Rancher $INSTANCE_NAME deletion"

## Check needed arguments
if [ "$#" -ne 2 ]; then
  DELETE_PREFLIGHT_CHECK="error"
  logToStderr $DELETE_STAGE "Not the correct amount of arguments passed, expected 2"
  logToStderr $DELETE_STAGE "Pass the following arguments: instance-name, job-id"
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
# Scale Rancher down to 0
logToStdout $DELETE_STAGE "INFO" "All Checks are OK, run kubectl delete namespace"
kubectl delete namespace $INSTANCE_NAME > /dev/null 2>&1
# TODO: use tmux to avoid kubectl delete namespace command to finish, it takes to long
# tmux new -d /opt/webhook-scripts/modules/delete-rancher-namespace.bash $INSTANCE_NAME $STARTTIME


# Check if kubectl was successfull
if (( $? != "0" )); then
  logToStderr $DELETE_STAGE "kubectl delete namespace not successful"
  webhookResponse "error" "kubectl delete namespace not successful"
  exit 0
else
  logToStdout $DELETE_STAGE "INFO" "FINISHED successfully sent delete command for $INSTANCE_NAME"
  webhookResponse "stopping" "Successfully sent delete command for $INSTANCE_NAME"
  unset DELETE_STAGE
  exit 0
fi