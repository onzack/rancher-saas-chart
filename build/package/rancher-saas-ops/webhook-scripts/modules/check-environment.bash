#!/bin/bash

## Comments
# We use exit 0 also for failues, with exti 1 the webhook does not reply with out custom error message

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

## Define variables
ENV_CHECK="undefined"
ENV_CHECK_STAGE="envcheck"


## The actual script
# Check for needed files
if [ ! -f $ENVIRONMENT_VALUES_FILE ]
  then
    ENV_CHECK="error"
    logToStderr $ENV_CHECK_STAGE "Environment values file does not exist"
fi

# Check for needed environment variables
if [[ ! -v ENVIRONMENT_VALUES_FILE ]]
  then
    ENV_CHECK="error"
    logToStderr $ENV_CHECK_STAGE "Environment variable ENVIRONMENT_VALUES_FILE not set"
fi

if [[ ! -v INGRESS_KEY_BASE64 ]]
  then
    ENV_CHECK="error"
    logToStderr $ENV_CHECK_STAGE "Environment variable INGRESS_KEY_BASE64 not set"
fi

if [[ ! -v INGRESS_CRT_BASE64 ]]
  then
    ENV_CHECK="error"
    logToStderr $ENV_CHECK_STAGE "Environment variable INGRESS_CRT_BASE64 not set"
fi

if [[ ! -v INGRESS_CA_CRT_BASE64 ]]
  then
    ENV_CHECK="error"
    logToStderr $ENV_CHECK_STAGE "Environment variable INGRESS_CA_CRT_BASE64 not set"
fi

if [[ ! -v DOMAIN ]]
  then
    ENV_CHECK="error"
    logToStderr $ENV_CHECK_STAGE "Environment variable DOMAIN not set"
fi

if [[ ! -v RANCHER_CLUSTER_ID ]]
  then
    ENV_CHECK="error"
    logToStderr $ENV_CHECK_STAGE "Environment variable RANCHER_CLUSTER_ID not set"
fi

if [[ ! -v RANCHER_PROJECT_ID ]]
  then
    ENV_CHECK="error"
    logToStderr $ENV_CHECK_STAGE "Environment variable RANCHER_PROJECT_ID not set"
fi

## Check ENF_CHECK before proceede
if [ "$ENV_CHECK" == "error" ]; then
  logToStderr $ENV_CHECK_STAGE "Environment variables not correct"
  exit 1
fi

unset ENV_CHECK_STAGE

exit 0