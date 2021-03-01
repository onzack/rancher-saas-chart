#!/bin/bash

STARTTIME=$(date +%s.%N)

## Comments
# We use exit 0 also for failues, with exti 1 the webhook does not reply with out custom error message 

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
  DURATION=$(echo "$ENDTIME - $STARTTIME" | bc -l)
}

errorlog () {
  local MESSAGE="$1"
  if [ -z "$JOB_ID" ]; then
    echo "Job-ID: 0 - ERROR - Stage: update - $MESSAGE" > $ERRORLOGTARGET
  else
    echo "Job-ID: $JOB_ID - ERROR - Stage: update - $MESSAGE" > $ERRORLOGTARGET
  fi
}

oklog () {
  local TYPE="$1"
  local MESSAGE="$2"
  if [ -z "$JOB_ID" ]; then
    echo "Job-ID: 0 - $TYPE - Stage: update - $MESSAGE" > $OKLOGTARGET
  else
    echo "Job-ID: $JOB_ID - $TYPE - Stage: update - $MESSAGE" > $OKLOGTARGET
  fi
}

returnlog () {
  local MESSAGE="$1"
  if [ -z "$JOB_ID" ]; then
    echo "{ \"job-id\":\"0\", \"status\":\"$STATUS\", \"duration\":\"$DURATION\", \"message\":\"$MESSAGE\" }"
  else
    echo "{ \"job-id\":\"$JOB_ID\", \"status\":\"$STATUS\", \"duration\":\"$DURATION\", \"message\":\"$MESSAGE\" }"
  fi
}

## Check for needed files
if [ ! -f $ENVIRONMENT_VALUES_FILE ]
  then
    STATUS="error"
    errorlog "Environment values file does not exist"
fi

## Check for needed environment variables
if [[ ! -v ENVIRONMENT_VALUES_FILE ]]
  then
    STATUS="error"
    errorlog "Environment variable ENVIRONMENT_VALUES_FILE not set"
fi

if [[ ! -v INGRESS_KEY_BASE64 ]]
  then
    STATUS="error"
    errorlog "Environment variable INGRESS_KEY_BASE64 not set"
fi

if [[ ! -v INGRESS_CRT_BASE64 ]]
  then
    STATUS="error"
    errorlog "Environment variable INGRESS_CRT_BASE64 not set"
fi

if [[ ! -v INGRESS_CA_CRT_BASE64 ]]
  then
    STATUS="error"
    errorlog "Environment variable INGRESS_CA_CRT_BASE64 not set"
fi

if [[ ! -v DOMAIN ]]
  then
    STATUS="error"
    errorlog "Environment variable DOMAIN not set"
fi

## Check needed arguments
if [ "$#" -ne 3 ]; then
  STATUS="error"
  errorlog "Not the correct amount of arguments passed, expected 3"
  errorlog "Pass the following arguments: instance-name, size, job-id"
fi

## Check kube-api connection
kubectl get namespaces >> /dev/null
if (( $? != "0" ))
  then
    STATUS="error"
    errorlog "Not able to connect to kube-api"
fi

## Check status before proceede wiht actual script
if [ "$STATUS" == "error" ]; then
  STATUS="error"
  setduration
  errorlog "Something with the configuration is wrong, duration $DURATION ms"
  returnlog "Configuration not correct"
  exit 0
fi

## The actual script
# Update Rancher SaaS with Helm
oklog "INFO" "All Checks are OK, run Helm upgrade"
helm upgrade --install --create-namespace -n $INSTANCE_NAME \
  -f /etc/rancher-saas/helm/size-$SIZE.yaml \
  -f $ENVIRONMENT_VALUES_FILE \
  --set rancher.size=$SIZE \
  --set ingress.TLSkey=$INGRESS_KEY_BASE64 \
  --set ingress.TLScert=$INGRESS_CRT_BASE64 \
  --set ingress.CAcert=$INGRESS_CA_CRT_BASE64 \
  --set rancher.instanceName=$INSTANCE_NAME \
  --set ingress.domain=$DOMAIN \
  $INSTANCE_NAME /etc/rancher-saas/helm >> /dev/null

# Check if Helm was successfull
if (( $? != "0" )); then
  STATUS="error"
  setduration
  errorlog "Helm did not complete successully, duration $DURATION ms"
  returnlog "Helm not successfull"
  exit 0
else
  STATUS="updating"
  setduration
  oklog "OK" "Successfully started $INSTANCE_NAME update"
  returnlog "Successfully started $INSTANCE_NAME update"
fi

# Start the script for the initial rancher configuration and send it to the background
tmux new -d /opt/webhook-scripts/check-rancher-health.bash $INSTANCE_NAME $JOB_ID $STARTTIME

STATUS="ok"
setduration
oklog "OK" "Started health check script after $DURATION ms"
exit 0