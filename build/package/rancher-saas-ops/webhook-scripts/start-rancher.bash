#!/bin/bash

## Comments
# We use exit 0 also for failues, with exti 1 the webhook does not reply with out custom error message 

STARTTIME=$(date +%s%3N)

## Import other scripts
# logging.bash for functions logToStderr, logToStdout and webhookResponse
source /opt/webhook-scripts/modules/logging.bash

## Expected arguments
# $1: Rancher SaaS instance name, like: rancher-saas-dev
# $3: Job ID, integer

## Save passed arguments
readonly INSTANCE_NAME="$1"
readonly JOB_ID="$2"

## Define global variables
START_PREFLIGHT_CHECK="undefined"
START_STAGE="start"

# Start logging
logToStdout $START_STAGE "INFO" "START Rancher $INSTANCE_NAME scale up to 1"

## Check needed arguments
if [ "$#" -ne 2 ]; then
  START_PREFLIGHT_CHECK="error"
  logToStderr $START_STAGE "Not the correct amount of arguments passed, expected 2"
  logToStderr $START_STAGE "Pass the following arguments: instance-name, job-id"
fi

## Check kube-api connection
kubectl get namespaces >> /dev/null
if (( $? != "0" ))
  then
    START_PREFLIGHT_CHECK="error"
    logToStderr $START_STAGE "Not able to connect to kube-api"
fi

## Check START_PREFLIGHT_CHECK before proceede wiht actual script
if [ "$START_PREFLIGHT_CHECK" == "error" ]; then
  logToStderr $START_STAGE "Configuration not correct"
  webhookResponse "error" "Configuration not correct"
  exit 0
fi

## The actual script
# Scale Rancher down to 0
logToStdout $START_STAGE "INFO" "All Checks are OK, run kubectl scale"
kubectl scale statefulset rancher -n $INSTANCE_NAME --replicas=1

# Check if kubectl was successfull
if (( $? != "0" )); then
  logToStderr $START_STAGE "kubectl scale not successful"
  webhookResponse "error" "kubeclt scale not successful"
  exit 0
else
  logToStdout $START_STAGE "INFO" "Successfully started $INSTANCE_NAME"
  webhookResponse "starting" "Successfully started $INSTANCE_NAME"
fi

# Start the script for the initial rancher configuration and send it to the background
logToStdout $START_STAGE "INFO" "Start health check script"
tmux new -d /opt/webhook-scripts/modules/check-rancher-health.bash $INSTANCE_NAME $JOB_ID $STARTTIME start

unset START_STAGE
exit 0