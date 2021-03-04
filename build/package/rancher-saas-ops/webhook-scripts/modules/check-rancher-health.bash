#!/bin/bash

## Comments
# We use exit 0 also for failues, with exti 1 the webhook does not reply with out custom error message

## Import other scripts
# logging.bash for functions logToStderr, logToStdout and webhookResponse
source /opt/webhook-scripts/modules/logging.bash

## Expected arguments
# $1: Rancher SaaS instance name, like: rancher-saas-dev
# $2: Job ID, integer
# $3 initial starttime, integer

## Save passed arguments
readonly INSTANCE_NAME="$1"
readonly JOB_ID="$2"
readonly INITIALSTARTTIME="$3"
readonly ACTION="$4"


## Define variables
HEALTH_CHECK_STAGE="healthcheck"

## Check needed arguments
if [ "$#" -ne 4 ]; then
  ENV_CHECK="error"
  logToStderr $HEALTH_CHECK_STAGE "Not the correct amount of arguments passed, expected 4"
  logToStderr $HEALTH_CHECK_STAGE "Pass the following arguments: instance-name, job-id, initial starttime and action"
fi

## Check ENV_CHECK before proceede wiht actual script
if [ "$ENV_CHECK" == "error" ]; then
  logToStderr $HEALTH_CHECK_STAGE "Configuration not correct"
  exit 0
fi

## The actual script
# Wait 5 minutes for Rancher go get ready
logToStdout $HEALTH_CHECK_STAGE "INFO" "Start waiting 5 Minutes for Rancher $INSTANCE_NAME go get ready"
HEALTH="notok"
TRY="360"
while (( $TRY > 0 ))
  do
    HEALTH=$(curl -k -s https://$INSTANCE_NAME.$DOMAIN/healthz | head -n 1)
    # echo "DEBUG - The HEALT environment varialbe is: $HEALTH"
    if [ "$HEALTH" == "ok" ]; then
      if [ "$ACTION" == "update" ]; then
        logToStdout $HEALTH_CHECK_STAGE "INFO" "FINISHED update, Rancher $INSTANCE_NAME up, running and healthy"
      else
        logToStdout $HEALTH_CHECK_STAGE "INFO" "Rancher $INSTANCE_NAME up, running and healthy"
      fi  
      exit 0
    else
      logToStdout $HEALTH_CHECK_STAGE "INFO" "Rancher $INSTANCE_NAME is not ready yet, timeout in $TRY seconds"
      sleep 5
      TRY=$(($TRY - 5))
    fi
done

logToStderr $HEALTH_CHECK_STAGE "FINISHED with timeout while waiting for Rancher $INSTANCE_NAME"

unset HEALTH_CHECK_STAGE
exit 0