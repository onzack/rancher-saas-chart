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
readonly JOB_ID="$2"

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
  local ENDTIME=$(date +%s.%N)
  DURATION=$(echo "$ENDTIME - $STARTTIME" | bc -l | sed -e 's/^\./0./')
}

errorlog () {
  local MESSAGE="$1"
  if [ -z "$JOB_ID" ]; then
    echo "Job-ID: 0 - ERROR - Stage: health - $MESSAGE" > $ERRORLOGTARGET
  else
    echo "Job-ID: $JOB_ID - ERROR - Stage: health - $MESSAGE" > $ERRORLOGTARGET
  fi
}

oklog () {
  local TYPE="$1"
  local MESSAGE="$2"
  if [ -z "$JOB_ID" ]; then
    echo "Job-ID: 0 - $TYPE - Stage: health - $MESSAGE" > $OKLOGTARGET
  else
    echo "Job-ID: $JOB_ID - $TYPE - Stage: health - $MESSAGE" > $OKLOGTARGET
  fi
}

## Check for needed environment variables
if [[ ! -v DOMAIN ]]
  then
    STATUS="error"
    errorlog "Environment variable DOMAIN not set"
fi

## Check needed arguments
if [ "$#" -ne 2 ]; then
  STATUS="error"
  errorlog "Not the correct amount of arguments passed, expected 2"
  errorlog "Pass the following arguments: instance-name, job-id"
fi

## Check status before proceede wiht actual script
if [ "$STATUS" == "error" ]; then
  STATUS="error"
  setduration
  errorlog "Something with the configuration is wrong, duration $DURATION seconds"
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
      setduration
      oklog "OK" "Updated Rancher $INSTANCE_NAME successfully, duration $DURATION seconds"
      returnlog "Updated Rancher $INSTANCE_NAME successfully"
      exit 0
    else
      oklog "INFO" "Rancher $INSTANCE_NAME is not ready yet... $TRY seconds remaining until timeout"
      sleep 5
      TRY=$(($TRY - 5))
    fi
done

STATUS="error"
setduration
errorlog "Time out while waiting for Rancher $INSTANCE_NAME, duration $DURATION seconds"
returnlog "Timeout while waiting for Rancher $INSTANCE_NAME"
exit 0