#!/bin/bash

STARTTIME=$(date +%s.%N)

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
if [ -f /var/run/secrets/kubernetes.io/serviceaccount/ca.crt ]
  then
    OKLOGTARGET="/proc/1/fd/1"
    ERRORLOGTARGET="/proc/1/fd/2"
  else
    OKLOGTARGET="/dev/stdout"
    ERRORLOGTARGET="/dev/stderr"
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
    echo "ERROR - Job-ID: 0, $MESSAGE" > $ERRORLOGTARGET
  else
    echo "ERROR - Job-ID: $JOB_ID, $MESSAGE" > $ERRORLOGTARGET
  fi
}

oklog () {
  local TYPE="$1"
  local MESSAGE="$2"
  if [ -z "$JOB_ID" ]; then
    echo "$TYPE - Job-ID: 0, $MESSAGE" > $OKLOGTARGET
  else
    echo "$TYPE - Job-ID: $JOB_ID, $MESSAGE" > $OKLOGTARGET
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
kubectl get endpoints -n default kubernetes >> /dev/null
if (( $? != "0" ))
  then
    STATUS="error"
    errorlog "Not able to connect to kube-api"
fi

## Check status before proceede wiht actual script
if [ "$STATUS" == "error" ]; then
  STATUS="error"
  setduration
  errorlog "Something with the configuration is wrong, duration $DURATION seconds"
  returnlog "Configuration not correct"
  exit 1
fi

## The actual script
# Update Rancher SaaS with Helm
oklog "INFO" "All Checks are OK, run Helm upgrade"
helm upgrade --install --create-namespace -n $INSTANCE_NAME \
  -f /etc/rancher-saas/helm/size-$SIZE.yaml \
  -f $ENVIRONMENT_VALUES_FILE \
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
  errorlog "Helm did not complete successully, duration $DURATION seconds"
  returnlog "Helm not successfull"
  exit 1
else
  STATUS="updating"
  setduration
  oklog "OK" "Successfully started $INSTANCE_NAME update"
  returnlog "Successfully started $INSTANCE_NAME update"
fi

## Wait 5 minutes for Rancher go get ready
oklog "INFO" "Start waiting for Rancher $INSTANCE_NAME go get ready"
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
exit 1