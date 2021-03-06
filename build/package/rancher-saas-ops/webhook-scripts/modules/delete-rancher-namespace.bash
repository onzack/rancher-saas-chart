#!/bin/bash

## Comments
# We use exit 0 also for failues, with exti 1 the webhook does not reply with out custom error message

## Import other scripts
# logging.bash for functions logToStderr, logToStdout and webhookResponse
source /opt/webhook-scripts/modules/logging.bash

## Expected arguments
# $1: Object ID, integer
# $2: Rancher SaaS instance name, like: rancher-saas-dev
# $3: Job ID, integer
# $4: Initial start time, integer

## Save passed arguments
export readonly OBJECT_ID="$1"
readonly INSTANCE_NAME="$2"
export readonly JOB_ID="$3"
readonly INITIALSTARTTIME="$4"

## Define variables
DELETE_NAMESPACE_STAGE="deltenamespace"

## Check needed arguments
if [ "$#" -ne 4 ]; then
  ENV_CHECK="error"
  logToStderr $DELETE_NAMESPACE_STAGE "Not the correct amount of arguments passed, expected 3"
  logToStderr $DELETE_NAMESPACE_STAGE "Pass the following arguments: object-id, instance-name, job-id and initial starttime"
fi

## Check ENV_CHECK before proceede wiht actual script
if [ "$ENV_CHECK" == "error" ]; then
  logToStderr $DELETE_NAMESPACE_STAGE "Configuration not correct"
  exit 0
fi

## The actual script
# Delete namespace
logToStdout $DELETE_NAMESPACE_STAGE "INFO" "All Checks are OK, run kubectl delete namespace"
kubectl delete namespace $INSTANCE_NAME > /dev/null 2>&1

# Check if kubectl was successfull
if (( $? != "0" )); then
  logToStderr $DELETE_NAMESPACE_STAGE "kubectl delete namespace not successful"
  unset DELETE_NAMESPACE_STAGE
  exit 0
else
  logToStdout $DELETE_NAMESPACE_STAGE "INFO" "FINISHED successfully sent delete command for $INSTANCE_NAME"
  unset DELETE_NAMESPACE_STAGE
  exit 0
fi