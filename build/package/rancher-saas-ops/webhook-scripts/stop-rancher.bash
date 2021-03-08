#!/bin/bash

## Comments
# We use exit 0 also for failues, with exti 1 the webhook does not reply with out custom error message 

export STARTTIME=$(date +%s%3N)

## Import other scripts
# logging.bash for functions logToStderr, logToStdout and webhookResponse
source /opt/webhook-scripts/modules/logging.bash

## Expected arguments
# $1: Rancher SaaS instance name, like: rancher-saas-dev
# $3: Job ID, integer

## Save passed arguments
readonly INSTANCE_NAME="$1"
export readonly JOB_ID="$2"

## Define global variables
STOP_PREFLIGHT_CHECK="undefined"
STOP_STAGE="stop"

# Start logging
logToStdout $STOP_STAGE "INFO" "START Rancher $INSTANCE_NAME scale down to 0"

## Check needed arguments
if [ "$#" -ne 2 ]; then
  STOP_PREFLIGHT_CHECK="error"
  logToStderr $STOP_STAGE "Not the correct amount of arguments passed, expected 2"
  logToStderr $STOP_STAGE "Pass the following arguments: instance-name, job-id"
fi

## Check kube-api connection
kubectl get namespaces >> /dev/null
if (( $? != "0" ))
  then
    STOP_PREFLIGHT_CHECK="error"
    logToStderr $STOP_STAGE "Not able to connect to kube-api"
fi

## Check STOP_PREFLIGHT_CHECK before proceede wiht actual script
if [ "$STOP_PREFLIGHT_CHECK" == "error" ]; then
  logToStderr $STOP_STAGE "Configuration not correct"
  webhookResponse "error" "Configuration not correct"
  exit 0
fi

## The actual script
# Scale Rancher down to 0
logToStdout $STOP_STAGE "INFO" "All Checks are OK, run kubectl scale"
kubectl scale statefulset rancher -n $INSTANCE_NAME --replicas=0

# Check if kubectl was successfull
if (( $? != "0" )); then
  logToStderr $STOP_STAGE "kubectl scale not successful"
  webhookResponse "error" "kubeclt scale not successful"
  exit 0
else
  logToStdout $STOP_STAGE "INFO" "FINISHED successfully stopped $INSTANCE_NAME"
  webhookResponse "stopping" "Successfully stopped $INSTANCE_NAME"
fi

unset STOP_STAGE
exit 0