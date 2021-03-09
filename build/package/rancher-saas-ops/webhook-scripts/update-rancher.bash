#!/bin/bash

## Comments
# We use exit 0 also for failues, with exti 1 the webhook does not reply with out custom error message 

STARTTIME=$(date +%s%3N)

## Import other scripts
# logging.bash for functions logToStderr, logToStdout and webhookResponse
source /opt/webhook-scripts/modules/logging.bash

## Expected environment variables
# ENVIRONMENT_VALUES_FILE
# INGRESS_KEY_BASE64
# INGRESS_CRT_BASE64
# INGRESS_CA_CRT_BASE64
# DOMAIN

## Expected arguments
# $1: Rancher SaaS instance name, like: rancher-saas-dev
# $2: Rancher SaaS size, like: S, M, or L
# $3: Job ID, integer

## Save passed arguments
readonly INSTANCE_NAME="$1"
readonly SIZE="$2"
readonly JOB_ID="$3"

## Define global variables
UPDATE_PREFLIGHT_CHECK="undefined"
UPDATE_STAGE="update"

# Start logging
logToStdout $UPDATE_STAGE "INFO" "START Rancher $INSTANCE_NAME update"

## Check for needed environment variables
logToStdout $UPDATE_STAGE "INFO" "Start environment check script"
/opt/webhook-scripts/modules/check-environment.bash
if (( $? != "0" ))
  then
    UPDATE_PREFLIGHT_CHECK="error"
    logToStderr $UPDATE_STAGE "Environment check script failed"
  else
    logToStdout $UPDATE_STAGE "INFO" "Environment check script successful"
fi

## Check needed arguments
if [ "$#" -ne 3 ]; then
  UPDATE_PREFLIGHT_CHECK="error"
  logToStderr $UPDATE_STAGE "Not the correct amount of arguments passed, expected 3"
  logToStderr $UPDATE_STAGE "Pass the following arguments: instance-name, size, job-id"
fi

## Check kube-api connection
kubectl get namespaces > /dev/null 2>&1
if (( $? != "0" ))
  then
    UPDATE_PREFLIGHT_CHECK="error"
    logToStderr $UPDATE_STAGE "Not able to connect to kube-api"
fi

## Check UPDATE_PREFLIGHT_CHECK before proceede wiht actual script
if [ "$UPDATE_PREFLIGHT_CHECK" == "error" ]; then
  logToStderr $UPDATE_STAGE "Configuration not correct"
  webhookResponse "error" "Configuration not correct"
  exit 0
fi

## The actual script
# Update Rancher SaaS with Helm
logToStdout $UPDATE_STAGE "INFO" "All Checks are OK, run Helm upgrade"
helm upgrade -n $INSTANCE_NAME \
  -f /etc/rancher-saas/helm/size-$SIZE.yaml \
  -f $ENVIRONMENT_VALUES_FILE \
  --set rancher.size=$SIZE \
  --set ingress.TLSkey=$INGRESS_KEY_BASE64 \
  --set ingress.TLScert=$INGRESS_CRT_BASE64 \
  --set ingress.CAcert=$INGRESS_CA_CRT_BASE64 \
  --set rancher.instanceName=$INSTANCE_NAME \
  --set ingress.domain=$DOMAIN \
  $INSTANCE_NAME /etc/rancher-saas/helm > /dev/null 2>&1

# Check if Helm was successfull
if (( $? != "0" )); then
  logToStderr $UPDATE_STAGE "Helm not successful"
  webhookResponse "error" "Helm not successful"
  exit 0
else
  logToStdout $UPDATE_STAGE "INFO" "Successfully started $INSTANCE_NAME update"
  webhookResponse "updating" "Successfully started $INSTANCE_NAME update"
fi

# Start the script for the initial rancher configuration and send it to the background
logToStdout $UPDATE_STAGE "INFO" "Start health check script"
tmux new -d /opt/webhook-scripts/modules/check-rancher-health.bash $INSTANCE_NAME $JOB_ID $STARTTIME update

unset UPDATE_STAGE
exit 0