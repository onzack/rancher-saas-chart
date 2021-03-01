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
# RANCHER_CLUSTER_ID
# RANCHER_PROJECT_ID

## Expected arguments
# $1: Rancher SaaS instance name, like: rancher-saas-dev
# $2: Rancher SaaS size, like: S, M, or L
# $3: Rancher SaaS admin password
# $4: Job ID, integer

## Save passed arguments
readonly INSTANCE_NAME="$1"
readonly SIZE="$2"
readonly ADMIN_PW="$3"
readonly JOB_ID="$4"

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
    echo "Job-ID: 0 - ERROR - Stage: deploy - $MESSAGE" > $ERRORLOGTARGET
  else
    echo "Job-ID: $JOB_ID - ERROR - Stage: deploy - $MESSAGE" > $ERRORLOGTARGET
  fi
}

oklog () {
  local TYPE="$1"
  local MESSAGE="$2"
  if [ -z "$JOB_ID" ]; then
    echo "Job-ID: 0 - $TYPE - Stage: deploy - $MESSAGE" > $OKLOGTARGET
  else
    echo "Job-ID: $JOB_ID - $TYPE - Stage: deploy - $MESSAGE" > $OKLOGTARGET
  fi
}

returnlog () {
  local MESSAGE="$1"
  if [ -z "$JOB_ID" ]; then
    # duration as millims
    # status: error, deploying
    echo "{ \"jobId\":0, \"status\":\"$STATUS\", \"duration\":$DURATION, \"message\":\"$MESSAGE\" }"
  else
    echo "{ \"jobId\":$JOB_ID, \"status\":\"$STATUS\", \"duration\":$DURATION, \"message\":\"$MESSAGE\" }"
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

if [[ ! -v RANCHER_CLUSTER_ID ]]
  then
    STATUS="error"
    errorlog "Environment variable RANCHER_CLUSTER_ID not set"
fi

if [[ ! -v RANCHER_PROJECT_ID ]]
  then
    STATUS="error"
    errorlog "Environment variable RANCHER_PROJECT_ID not set"
fi

## Check needed arguments
if [ "$#" -ne 4 ]; then
  STATUS="error"
  errorlog "Not the correct amount of arguments passed, expected 4"
  errorlog "Pass the following arguments: instance-name, size, password, job-id"
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
# Create Namespace
oklog "INFO" "Create namespace $INSTANCE_NAME"
cat << EOF | kubectl apply -f - >> /dev/null
apiVersion: v1
kind: Namespace
metadata:
  annotations:
    field.cattle.io/projectId: $RANCHER_CLUSTER_ID:$RANCHER_PROJECT_ID
  labels:
    field.cattle.io/projectId: $RANCHER_PROJECT_ID
    name: $INSTANCE_NAME
  name: $INSTANCE_NAME
EOF
if (( $? != "0" )); then
  STATUS="error"
  setduration
  errorlog "Create namespace $INSTANCE_NAME not successully, duration $DURATION ms"
  returnlog "Create namespace $INSTANCE_NAME not successful"
  exit 0
else
  STATUS="deploying"
  setduration
  oklog "OK" "Successfully created namespace $INSTANCE_NAME"
fi

# Deploy Rancher SaaS with Helm
oklog "INFO" "All Checks are OK, run Helm install"
helm upgrade --install -n $INSTANCE_NAME \
  -f /etc/rancher-saas/helm/size-$SIZE.yaml \
  -f $ENVIRONMENT_VALUES_FILE \
  --set rancher.size=$SIZE \
  --set ingress.TLSkey=$INGRESS_KEY_BASE64 \
  --set ingress.TLScert=$INGRESS_CRT_BASE64 \
  --set ingress.CAcert=$INGRESS_CA_CRT_BASE64 \
  --set rancher.instanceName=$INSTANCE_NAME \
  --set ingress.domain=$DOMAIN \
  $INSTANCE_NAME /etc/rancher-saas/helm >> /dev/null

# Check if Helm was successful
if (( $? != "0" )); then
  STATUS="error"
  setduration
  errorlog "Helm did not complete successully, duration $DURATION ms"
  returnlog "Helm not successful"
  exit 0
else
  STATUS="ok"
  setduration
  oklog "OK" "Successfully started $INSTANCE_NAME deployment"
  returnlog "Successfully started $INSTANCE_NAME deployment"
fi

# Start the script for the initial rancher configuration and send it to the background
tmux new -d /opt/webhook-scripts/initially-configure-rancher.bash $INSTANCE_NAME $ADMIN_PW $JOB_ID $STARTTIME

STATUS="ok"
setduration
oklog "OK" "Started initial rancher configuration script after $DURATION ms"
exit 0