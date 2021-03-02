#!/bin/bash

## Comments
# We use exit 0 also for failues, with exti 1 the webhook does not reply with out custom error message 

## Expected environment variables
# DOMAIN

## Expected arguments
# $1: Rancher SaaS instance name, like: rancher-saas-dev
# $2: Job ID, integer
# $3 initial starttime, integer

## Save passed arguments
readonly INSTANCE_NAME="$1"
readonly JOB_ID="$2"
readonly INITIALSTARTTIME="$3"

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
  DURATION=$(echo "$ENDTIME - $INITIALSTARTTIME" | bc -l)
}

errorlog () {
  local MESSAGE="$1"
  setduration
  echo "time=\"$(date +%d-%m-%Y\ %H:%M:%S)\" jobID=$JOB_ID level=error stage=deploy scriptDuration=$DURATION message=\"$MESSAGE\"" > $ERRORLOGTARGET
}

oklog () {
  local LEVEL="$1"
  local MESSAGE="$2"
  setduration
  echo "time=\"$(date +%d-%m-%Y\ %H:%M:%S)\" jobID=$JOB_ID level=$LEVEL stage=deploy scriptDuration=$DURATION message=\"$MESSAGE\"" > $OKLOGTARGET
}

## Check for needed environment variables
if [[ ! -v DOMAIN ]]
  then
    STATUS="error"
    errorlog "Environment variable DOMAIN not set"
fi

## Check needed arguments
if [ "$#" -ne 3 ]; then
  STATUS="error"
  errorlog "Not the correct amount of arguments passed, expected 3"
  errorlog "Pass the following arguments: instance-name, job-id, initial starttime"
fi

## Check status before proceede wiht actual script
if [ "$STATUS" == "error" ]; then
  errorlog "Configuration not correct"
  returnlog "Configuration not correct"
  exit 0
fi

## The actual script
# Wait 5 minutes for Rancher go get ready
oklog "INFO" "Start waiting 5 Minutes for Rancher $INSTANCE_NAME go get ready"
HEALTH="notok"
TRY="360"
while (( $TRY > 0 ))
  do
    HEALTH=$(curl -k -s https://$INSTANCE_NAME.$DOMAIN/healthz | head -n 1)
    # echo "DEBUG - The HEALT environment varialbe is: $HEALTH"
    if [ "$HEALTH" == "ok" ]; then
      STATUS="ok"
      oklog "-OK-" "Rancher $INSTANCE_NAME up, running and healthy"
      exit 0
    else
      oklog "INFO" "Rancher $INSTANCE_NAME is not ready yet, timeout in $TRY seconds"
      sleep 5
      TRY=$(($TRY - 5))
    fi
done

STATUS="error"
errorlog "Timeout while waiting for Rancher $INSTANCE_NAME"
returnlog "Timeout while waiting for Rancher $INSTANCE_NAME"
exit 0