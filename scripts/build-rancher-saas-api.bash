#!/bin/bash

# Prerequisites
# This script expects an arguemnt for the rkm-outpost docker tag

DOCKER_TAG=""
RANCHER_SAAS_API_HELM_TARGET_PATH="./build/package/rancher-saas-ops/helm"

# Check arguments
if [ "$#" -lt 1 ] 
  then
    echo "WARNING - This script expects one argument for the docker tag, you didn't pass one so the script uses the tag: latest"
    DOCKER_TAG="latest"
  elif [ "$#" -gt 1 ]
    then
      echo "ERROR - Your passed too much arguments. We expect only one, the docker tag. Abort..."
      exit 1
  else
      DOCKER_TAG=$1
fi
echo "INFO - Docker Tag is: $DOCKER_TAG"

# Copy Helm chart to build folder
echo "INFO - Start go build for rkm-outpost"
if [ -f $RANCHER_SAAS_API_HELM_TARGET_PATH ]
  then
    echo "WARNING - Helm Chart already existed in build folder and was deleted by this script to avoid conflicts"
    rm -r $RANCHER_SAAS_API_HELM_TARGET_PATH
fi
cp -rp ./deployments/kubernetes/helm/rancher-saas $RANCHER_SAAS_API_HELM_TARGET_PATH

# Docker Build
echo "INFO - Start docker build for rkm-outpost:$DOCKER_TAG"
docker build -t harbor.apps.lab.onzack.io/rancher-saas/rancher-saas-ops:$DOCKER_TAG ./build/package/rancher-saas-ops
if (( $? != "0" ))
  then
    echo "ERROR - Something went wrong with docker build"
    exit 1
  else
    echo "INFO - Finisched docker build for rancher-saas-ops:$DOCKER_TAG"
fi

# Cleanup
echo "INFO - Start cleanup"
rm -r $RANCHER_SAAS_API_HELM_TARGET_PATH
echo "INFO - Finisched cleanup"