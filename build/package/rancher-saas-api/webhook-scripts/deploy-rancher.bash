#!/bin/bash

STARTTIME=$(date +%s.%N)

## Expected environment variables
# ENVIRONMENT_VALUES_FILE
# WILDCARD_APPS_LAB_ONZACK_IO_KEY_BASE64
# WILDCARD_APPS_LAB_ONZACK_IO_CRT_BASE64
# LAB_ONZACK_IO_CA_BASE64
# DOMAIN

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

if [[ ! -v WILDCARD_APPS_LAB_ONZACK_IO_KEY_BASE64 ]]
  then
    STATUS="error"
    errorlog "Environment variable WILDCARD_APPS_LAB_ONZACK_IO_KEY_BASE64 not set"
fi

if [[ ! -v WILDCARD_APPS_LAB_ONZACK_IO_CRT_BASE64 ]]
  then
    STATUS="error"
    errorlog "Environment variable WILDCARD_APPS_LAB_ONZACK_IO_CRT_BASE64 not set"
fi

if [[ ! -v LAB_ONZACK_IO_CA_BASE64 ]]
  then
    STATUS="error"
    errorlog "Environment variable LAB_ONZACK_IO_CA_BASE64 not set"
fi

if [[ ! -v DOMAIN ]]
  then
    STATUS="error"
    errorlog "Environment variable DOMAIN not set"
fi

## Check needed arguments
if [ "$#" -ne 4 ]; then
  STATUS="error"
  errorlog "Not the correct amount of arguments passed, expected 4"
  errorlog "Pass the following arguments: instance-name, size, password, job-id"
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
# Deploy Rancher SaaS with Helm
oklog "INFO" "All Checks are OK, run Helm command"
helm upgrade --install --create-namespace -n $INSTANCE_NAME \
  -f /etc/rancher-saas/helm/size-$SIZE.yaml \
  -f $ENVIRONMENT_VALUES_FILE \
  --set ingress.TLSkey=$WILDCARD_APPS_LAB_ONZACK_IO_KEY_BASE64 \
  --set ingress.TLScert=$WILDCARD_APPS_LAB_ONZACK_IO_CRT_BASE64 \
  --set ingress.CAcert=$LAB_ONZACK_IO_CA_BASE64 \
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
  oklog "OK" "Run Helm command was successfull"
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
      oklog "OK" "Rancher $INSTANCE_NAME is up and running"
      # Get Rancher login token
      oklog "INFO" "Get Rancher login token"
      LOGINRESPONSE="undefined"
      LOGINTOKEN="undefined"
      LOGINRESPONSE=`curl -s "https://$INSTANCE_NAME.$DOMAIN/v3-public/localProviders/local?action=login" \
        -H 'content-type: application/json' \
        --data-binary '{"username":"admin","password":"admin"}' \
        --insecure`
      # Check if Rancher login was successfull
      if (( $? != "0" )); then
        STATUS="error"
        setduration
        errorlog "Rancher login did not complete successully, duration $DURATION seconds"
        returnlog "Rancher login not successfull"
        exit 1
      else
        oklog "OK" "Rancher login was successfull"
      fi
      LOGINTOKEN=`echo $LOGINRESPONSE | jq -r .token`
      #oklog "DEBUG" "Rancher login token: $LOGINTOKEN"
      
      # Set Rancher admin password
      oklog "INFO" "Set Rancher admin password"
      curl -s "https://$INSTANCE_NAME.$DOMAIN/v3/users?action=changepassword" \
        -H 'content-type: application/json' \
        -H "Authorization: Bearer $LOGINTOKEN" \
        --data-binary '{"currentPassword":"admin","newPassword":"'$ADMIN_PW'"}' \
        --insecure
      # Check if Rancher admin passwort setting was successfull
      if (( $? != "0" )); then
        STATUS="error"
        setduration
        errorlog "Set Rancher admin password did not complete successully, duration $DURATION seconds"
        returnlog "Set Rancher password not successfull"
        exit 1
      else
        oklog "OK" "Set Rancher admin password was successfull"
      fi      
      # Set Rancher URL
      oklog "INFO" "Set Rancher URL"
      curl -s "https://$INSTANCE_NAME.$DOMAIN/v3/settings/server-url" \
        -H 'content-type: application/json' \
        -H "Authorization: Bearer $LOGINTOKEN" \
        -X PUT \
        --data-binary '{"name":"server-url","value":"'$INSTANCE_NAME.$DOMAIN'"}' \
        --insecure >> /dev/null
      # Check if Rancher URL setting was successfull
      if (( $? != "0" )); then
        STATUS="error"
        setduration
        errorlog "Set Rancher URL did not complete successully, duration $DURATION seconds"
        returnlog "Set Rancher URL not successfull"
        exit 1
      else
        oklog "OK" "Set Rancher URL was successfull"
      fi
      STATUS="ok"
      setduration
      oklog "OK" "Deployed Rancher $INSTANCE_NAME successfully, duration $DURATION seconds"
      returnlog "Deployed Rancher $INSTANCE_NAME successfully"
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