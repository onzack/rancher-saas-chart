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

## Define varialbes for log output
if [ -f /var/run/secrets/kubernetes.io/serviceaccount/ca.crt ]
  then
    OKLOGTARGET="/proc/1/fd/1"
    ERRORLOGTARGET="/proc/1/fd/2"
  else
    OKLOGTARGET="/dev/stdout"
    ERRORLOGTARGET="/dev/stderr"
fi

## Define status variable
STATUS="undefined"

## Check for needed files
if [ ! -f $ENVIRONMENT_VALUES_FILE ]
  then
    if [ -z "$4" ]; then
      echo "ERROR - Job-ID: 0, Environment values file does not exist" > $ERRORLOGTARGET
    else
      echo "ERROR - Job-ID: $4, Environment values file does not exist" > $ERRORLOGTARGET
    fi
    STATUS="error"
fi

## Check for needed environment variables
if [[ ! -v ENVIRONMENT_VALUES_FILE ]]
  then
    if [ -z "$4" ]; then
      echo "ERROR - Job-ID: 0, Environment variable ENVIRONMENT_VALUES_FILE not set" > $ERRORLOGTARGET
    else
      echo "ERROR - Job-ID: $4, Environment variable ENVIRONMENT_VALUES_FILE not set" > $ERRORLOGTARGET
    fi
    STATUS="error"
fi

if [[ ! -v WILDCARD_APPS_LAB_ONZACK_IO_KEY_BASE64 ]]
  then
    if [ -z "$4" ]; then
      echo "ERROR - Job-ID: 0, Environment variable WILDCARD_APPS_LAB_ONZACK_IO_KEY_BASE64 not set" > $ERRORLOGTARGET
    else
      echo "ERROR - Job-ID: $4, Environment variable WILDCARD_APPS_LAB_ONZACK_IO_KEY_BASE64 not set" > $ERRORLOGTARGET
    fi
    STATUS="error"
fi

if [[ ! -v WILDCARD_APPS_LAB_ONZACK_IO_CRT_BASE64 ]]
  then
    if [ -z "$4" ]; then
      echo "ERROR - Job-ID: 0, Environment variable WILDCARD_APPS_LAB_ONZACK_IO_CRT_BASE64 not set" > $ERRORLOGTARGET
    else
      echo "ERROR - Job-ID: $4, Environment variable WILDCARD_APPS_LAB_ONZACK_IO_CRT_BASE64 not set" > $ERRORLOGTARGET
    fi
    STATUS="error"
fi

if [[ ! -v LAB_ONZACK_IO_CA_BASE64 ]]
  then
    if [ -z "$4" ]; then
      echo "ERROR - Job-ID: 0, Environment variable LAB_ONZACK_IO_CA_BASE64 not set" > $ERRORLOGTARGET
    else
      echo "ERROR - Job-ID: $4, Environment variable LAB_ONZACK_IO_CA_BASE64 not set" > $ERRORLOGTARGET
    fi
    STATUS="error"
fi

if [[ ! -v DOMAIN ]]
  then
    if [ -z "$4" ]; then
      echo "ERROR - Job-ID: 0, Environment variable DOMAIN not set" > $ERRORLOGTARGET
    else
      echo "ERROR - Job-ID: $4, Environment variable DOMAIN not set" > $ERRORLOGTARGET
    fi
    STATUS="error"
fi

## Check needed arguments
if [ "$#" -ne 4 ]; then
  if [ -z "$4" ]; then
    echo "ERROR - Job-ID: 0, Not enougth arguments passed, expected 4 got $#" > $ERRORLOGTARGET
    echo "ERROR - Job-ID: 0, Pass the following arguments: instance-name, size, password, job-id" > $ERRORLOGTARGET
  else
    echo "ERROR - Job-ID: $4, Not enougth arguments passed, expected 4 got $#" > $ERRORLOGTARGET
    echo "ERROR - Job-ID: $4, Pass the following arguments: instance-name, size, password, job-id" > $ERRORLOGTARGET
  fi
  STATUS="error"
fi

## Check kube-api connection
kubectl get endpoints -n default kubernetes >> /dev/null
if (( $? != "0" ))
  then
    if [ -z "$4" ]; then
      echo "ERROR - Job-ID: 0, Not able to connect to kube-api" > $ERRORLOGTARGET
    else
      echo "ERROR - Job-ID: $4, Not able to connect to kube-api" > $ERRORLOGTARGET
    fi
    STATUS="error"
fi

## Check status before proceede wiht actual script
if [ "$STATUS" == "error" ]; then
    ENDTIME=$(date +%s.%N)
    DURATION=$(echo "$ENDTIME - $STARTTIME" | bc -l | sed -e 's/^\./0./')
    if [ -z "$4" ]; then
      echo "ERROR - Job-ID: 0, Something with the configuration is wrong, duration $DURATION seconds" > $ERRORLOGTARGET
      echo "{ "job-id":"0", "status":"error", "duration":"$DURATION", "message":"Configuration not correct" }"
    else
      echo "ERROR - Job-ID: $4, Something with the configuration is wrong, duration $DURATION seconds" > $ERRORLOGTARGET
      echo "{ "job-id":"$4", "status":"error", "duration":"$DURATION", "message":"Configuration not correct" }"
    fi
    exit 1
fi

## The actual script
# Deploy Rancher SaaS with Helm
echo "INFO - Job-ID: $4, All Checks are OK, run Helm command" > $OKLOGTARGET
helm upgrade --install --create-namespace -n $1 \
  -f /etc/rancher-saas/helm/size-$2.yaml \
  -f $ENVIRONMENT_VALUES_FILE \
  --set ingress.TLSkey=$WILDCARD_APPS_LAB_ONZACK_IO_KEY_BASE64 \
  --set ingress.TLScert=$WILDCARD_APPS_LAB_ONZACK_IO_CRT_BASE64 \
  --set ingress.CAcert=$LAB_ONZACK_IO_CA_BASE64 \
  --set rancher.instanceName=$1 \
  --set ingress.domain=$DOMAIN \
  $1 /etc/rancher-saas/helm >> /dev/null

# Check if Helm was successfull
if (( $? != "0" ))
  then
    ENDTIME=$(date +%s.%N)
    DURATION=$(echo "$ENDTIME - $STARTTIME" | bc -l | sed -e 's/^\./0./')
    echo "ERROR - Job-ID: $4, Helm did not complete successully, duration $DURATION seconds" > $ERRORLOGTARGET
    echo "{ "job-id":"$4", "status":"error", "duration":"$DURATION", "message":"Helm not successfull" }"
    exit 1
  else
    echo "OK - Job-ID: $4, Run Helm command was successfull" > $OKLOGTARGET
fi

## Wait 5 minutes for Rancher go get ready
echo "INFO - Job-ID: $4, Start waiting for Rancher $1 go get ready" > $OKLOGTARGET
HEALTH="notok"
TRY="360"
while (( $TRY > 0 ))
  do
    HEALTH=$(curl -k -s https://$1.$DOMAIN/healthz | head -n 1)
    # echo "DEBUG - The HEALT environment varialbe is: $HEALTH"
    if [ "$HEALTH" == "ok" ]; then
      # # Get Rancher login token
      # echo "INFO - Job-ID: $4, Get Rancher login token" > $OKLOGTARGET
      # LOGINRESPONSE="undefinde"
      # LOGINTOKEN="undefinde"
      # LOGINRESPONSE=`curl -s 'https://$1.$DOMAIN/v3-public/localProviders/local?action=login' \
      #   -H 'content-type: application/json' \
      #   --data-binary '{"username":"admin","password":"admin"}' \
      #   --insecure`
      # LOGINTOKEN=`echo $LOGINRESPONSE | jq -r .token`
      # echo "DEBUG - Job-ID: $4, Rancher login token: $LOGINTOKEN" > $OKLOGTARGET
      # 
      # # Set Rancher admin password
      # echo "INFO - Job-ID: $4, Set Rancher admin password" > $OKLOGTARGET
      # curl -s 'https://$1.$DOMAIN/v3/users?action=changepassword' \
      #   -H 'content-type: application/json' \
      #   -H "Authorization: Bearer $LOGINTOKEN" \
      #   --data-binary '{"currentPassword":"admin","newPassword":"$3"}' \
      #   --insecure
      # 
      # # Set Rancher URL
      # echo "INFO - Job-ID: $4, Set Rancher URL" > $OKLOGTARGET
      # curl -s 'https://$1.$DOMAIN/v3/settings/server-url' \
      #   -H 'content-type: application/json' \
      #   -H "Authorization: Bearer $LOGINTOKEN" \
      #   -X PUT \
      #   --data-binary '{"name":"server-url","value":"'$1.$DOMAIN'"}' \
      #   --insecure
      # 
      ENDTIME=$(date +%s.%N)
      DURATION=$(echo "$ENDTIME - $STARTTIME" | bc -l | sed -e 's/^\./0./')
      echo "OK - Job-ID: $4, Rancher $1 is up and running, duration $DURATION seconds" > $OKLOGTARGET
      echo "{ "job-id":"$4", "status":"ok", "duration":"$DURATION", "message":"Rancher $1 up and running" }"
      exit 0
    else
      echo "INFO - Job-ID: $4, Rancher $1 is not ready yet... $TRY seconds remaining until timeout" > $OKLOGTARGET
      sleep 5
      TRY=$(($TRY - 5))
    fi
done

ENDTIME=$(date +%s.%N)
DURATION=$(echo "$ENDTIME - $STARTTIME" | bc -l | sed -e 's/^\./0./')
echo "ERROR - Job-ID: $4, Time out while waiting for Rancher $1, duration $DURATION seconds" > $OKLOGTARGET
echo "{ "job-id":"$4", "status":"error", "duration":"$DURATION", "message":"Timeout" }"
exit 1