#!/bin/bash

STARTTIME=$(date +%s%3N)

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
  setduration
  echo "time=\"$(date +%d-%m-%Y\ %H:%M:%S)\" level=ERROR jobID=$JOB_ID stage=update scriptDuration=$DURATION message=\"$MESSAGE\"" > $ERRORLOGTARGET
}

oklog () {
  local LEVEL="$1"
  local MESSAGE="$2"
  setduration
  echo "time=\"$(date +%d-%m-%Y\ %H:%M:%S)\" level=$LEVEL jobID=$JOB_ID stage=update scriptDuration=$DURATION message=\"$MESSAGE\"" > $OKLOGTARGET
}

returnlog () {
  local MESSAGE="$1"
  setduration
  echo "{ \"jobId\":$JOB_ID, \"status\":\"$STATUS\", \"duration\":$DURATION, \"message\":\"$MESSAGE\" }"
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
  errorlog "Configuration not correct"
  returnlog "Configuration not correct"
  exit 0
fi

## The actual script
# Update Rancher SaaS with Helm
oklog "INFO" "All Checks are OK, run Helm upgrade"
helm upgrade -n $INSTANCE_NAME \
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
  errorlog "Helm not successful"
  returnlog "Helm not successful"
  exit 0
else
  STATUS="updating"
  oklog "INFO" "Successfully started $INSTANCE_NAME update"
  returnlog "Successfully started $INSTANCE_NAME update"
fi

# Start the script for the initial rancher configuration and send it to the background
tmux new -d /opt/webhook-scripts/check-rancher-health.bash $INSTANCE_NAME $JOB_ID $STARTTIME

STATUS="ok"
oklog "INFO" "Started health check script"
exit 0