#!/bin/bash

## Comments
# We use exit 0 also for failues, with exti 1 the webhook does not reply with out custom error message

export STARTTIME=$(date +%s%3N)

## Import other scripts
# logging.bash for functions logToStderr, logToStdout and webhookResponse
source /opt/webhook-scripts/modules/logging.bash

## Expected environment variables
# ENVIRONMENT_VALUES_FILE
# INGRESS_KEY_BASE64
# INGRESS_CRT_BASE64
# INGRESS_CA_CRT_BASE64
# DOMAIN
# RANCHER_CLUSTER_ID
# RANCHER_PROJECT_ID

## Expected arguments
# $1: Object ID, integer
# $2: Rancher SaaS instance name, like: rancher-saas-dev
# $3: Rancher SaaS size, like: S, M, or L
# $4: Rancher SaaS admin password
# $5: Job ID, integer

## Save passed arguments
export readonly OBJECT_ID="$1"
readonly INSTANCE_NAME="$2"
### Convert size character to uppercase
readonly SIZE="${3^^}"
readonly ADMIN_PW="$4"
export readonly JOB_ID="$5"

## Define global variables
DEPLOY_PREFLIGHT_CHECK="undefined"
DEPLOY_STAGE="deploy"

# Start logging
logToStdout $DEPLOY_STAGE "INFO" "START Rancher $INSTANCE_NAME deployment"

## Check for needed environment variables
logToStdout $DEPLOY_STAGE "INFO" "Start environment check script"
/opt/webhook-scripts/modules/check-environment.bash
if (( $? != "0" ))
  then
    DEPLOY_PREFLIGHT_CHECK="error"
    logToStderr $DEPLOY_STAGE "Environment check script failed"
  else
    logToStdout $DEPLOY_STAGE "INFO" "Environment check script successful"
fi

## Check needed arguments
if [ "$#" -ne 5 ]; then
  DEPLOY_PREFLIGHT_CHECK="error"
  logToStderr $DEPLOY_STAGE "Not the correct amount of arguments passed, expected 4"
  logToStderr $DEPLOY_STAGE "Pass the following arguments: instance-name, size, password, job-id"
fi

## Check kube-api connection
kubectl get namespaces > /dev/null 2>&1
if (( $? != "0" ))
  then
    DEPLOY_PREFLIGHT_CHECK="error"
    logToStderr $DEPLOY_STAGE "Not able to connect to kube-api"
fi

## Check DEPLOY_PREFLIGHT_CHECK before proceede wiht actual script
if [ "$DEPLOY_PREFLIGHT_CHECK" == "error" ]; then
  logToStderr $DEPLOY_STAGE "Configuration not correct"
  webhookResponse "error" "Configuration not correct"
  exit 0
fi

## The actual script
# Create Namespace
logToStdout $DEPLOY_STAGE "INFO" "Create namespace $INSTANCE_NAME"
cat << EOF | kubectl apply -f - > /dev/null 2>&1
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
  logToStderr $DEPLOY_STAGE "Create namespace $INSTANCE_NAME not successful"
  webhookResponse "error" "Create namespace $INSTANCE_NAME not successful"
  exit 0
else
  logToStdout $DEPLOY_STAGE "INFO" "Successfully created namespace $INSTANCE_NAME"
fi

# Deploy Rancher SaaS with Helm
logToStdout $DEPLOY_STAGE "INFO" "All Checks are OK, run Helm install"
helm upgrade --install -n $INSTANCE_NAME \
  -f /etc/rancher-saas/helm/size-$SIZE.yaml \
  -f $ENVIRONMENT_VALUES_FILE \
  --set rancher.size=$SIZE \
  --set ingress.TLSkey=$INGRESS_KEY_BASE64 \
  --set ingress.TLScert=$INGRESS_CRT_BASE64 \
  --set ingress.CAcert=$INGRESS_CA_CRT_BASE64 \
  --set rancher.instanceName=$INSTANCE_NAME \
  --set ingress.domain=$DOMAIN \
  $INSTANCE_NAME /etc/rancher-saas/helm > /dev/null 2>&1

# Check if Helm was successful
if (( $? != "0" )); then
  logToStderr $DEPLOY_STAGE "Helm not successful"
  webhookResponse "error" "Helm not successful"
  exit 0
else
  logToStdout $DEPLOY_STAGE "INFO" "Successfully started $INSTANCE_NAME deployment"
  webhookResponse "deploying" "Successfully started $INSTANCE_NAME deployment"
fi

# Start the script for the initial rancher configuration and send it to the background
logToStdout $DEPLOY_STAGE "INFO" "Start initial rancher configuration script"
tmux new -d /opt/webhook-scripts/modules/initially-configure-rancher.bash $OBJECT_ID $INSTANCE_NAME $ADMIN_PW $JOB_ID $STARTTIME

unset DEPLOY_STAGE
exit 0