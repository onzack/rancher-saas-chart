#!/bin/bash

STARTTIME=$(date +%s%3N)

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
    ERRORLOGTARGET="/proc/1/f
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
    echo "Job-ID: 0 - ERROR - $MESSAGE" > $ERRORLOGTARGET
  else
    echo "Job-ID: $JOB_ID - ERROR - $MESSAGE" > $ERRORLOGTARGET
  fi
}

oklog () {
  local TYPE="$1"
  local MESSAGE="$2"
  if [ -z "$JOB_ID" ]; then
    echo "Job-ID: 0 - $TYPE - $MESSAGE" > $OKLOGTARGET
  else
    echo "Job-ID: $JOB_ID - $TYPE - $MESSAGE" > $OKLOGTARGET
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

cleanup () {
  unset LOGINRESPONSE
  unset LOGINTOKEN
  unset USERID
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
  errorlog "Something with the configuration is wrong, duration $DURATION ms"
  returnlog "Configuration not correct"
  exit 1
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
    name: rancher-saas-dev
  name: $INSTANCE_NAME
EOF
if (( $? != "0" )); then
  STATUS="error"
  setduration
  errorlog "Create namespace $INSTANCE_NAME not successully, duration $DURATION ms"
  returnlog "Create namespace $INSTANCE_NAME not successfull"
  exit 1
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
  exit 1
else
  STATUS="ok"
  setduration
  oklog "OK" "Successfully started $INSTANCE_NAME deployment"
  returnlog "Successfully started $INSTANCE_NAME deployment"
fi

## Wait 5 minutes for Rancher go get ready
oklog "INFO" "Start waiting for Rancher $INSTANCE_NAME go get ready"
HEALTH="notok"
TRY="360"
while (( $TRY > 0 ))
  do
    HEALTH=$(curl -k -s https://$INSTANCE_NAME.$DOMAIN/healthz | head -n 1)
    if [ "$HEALTH" == "ok" ]; then
      oklog "OK" "Rancher $INSTANCE_NAME is up and running"
      # Get Rancher login token
      oklog "INFO" "Get Rancher login token"
      LOGINRESPONSE="undefined"
      LOGINTOKEN="undefined"
      USERID="undefined"
      LOGINRESPONSE=`curl -s "https://$INSTANCE_NAME.$DOMAIN/v3-public/localProviders/local?action=login" \
        -H 'content-type: application/json' \
        --data-binary '{"username":"admin","password":"admin"}' \
        --insecure`
      # Check if Rancher login was successfull
      if (( $? != "0" )); then
        STATUS="error"
        setduration
        errorlog "Rancher login did not complete successully, duration $DURATION ms"
        cleanup
        exit 1
      else
        oklog "OK" "Rancher login was successfull"
      fi
    
      LOGINTOKEN=`echo $LOGINRESPONSE | jq -r .token`
      USERID=`echo $LOGINRESPONSE | jq -r .userId`
      #oklog "DEBUG" "Rancher login token: $LOGINTOKEN"
      #oklog "DEBUG" "Rancher admin userId: $USERID"
      
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
        errorlog "Set Rancher admin password did not complete successully, duration $DURATION ms"
        cleanup
        exit 1
      else
        oklog "OK" "Set Rancher admin password was successfull"
      fi

      # Force Rancher admin to change password on first login
      oklog "INFO" "Force Rancher admin to change password on first login"
      curl -X PUT -s "https://$INSTANCE_NAME.$DOMAIN/v3/users/$USERID" \
        -H 'content-type: application/json' \
        -H "Authorization: Bearer $LOGINTOKEN" \
        --data-binary '{"mustChangePassword": true}' \
        --insecure >> /dev/null
      # Check if forcing Rancher admin to change password on first login was successfull
      if (( $? != "0" )); then
        STATUS="error"
        setduration
        errorlog "Force Rancher admin to change password on first login not successfull, duration $DURATION ms"
        cleanup
        exit 1
      else
        oklog "OK" "Force Rancher admin to change password on first login was successfull"
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
        errorlog "Set Rancher URL did not complete successully, duration $DURATION ms"
        cleanup
        exit 1
      else
        oklog "OK" "Set Rancher URL was successfull"
      fi
      STATUS="ok"
      setduration
      oklog "OK" "Deployed Rancher $INSTANCE_NAME successfully, duration $DURATION ms"
      cleanup
      exit 0
    else
      oklog "INFO" "Rancher $INSTANCE_NAME is not ready yet, timeout in $TRY seconds"
      sleep 5
      TRY=$(($TRY - 5))
    fi
done

STATUS="error"
setduration
errorlog "Time out while waiting for Rancher $INSTANCE_NAME, duration $DURATION ms"
cleanup
exit 1