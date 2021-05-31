#!/bin/bash

## ATTENTION
# Does not work any more as the modules are not in the correct place

## Check if directory /etc/rancher-saas exists
if [ ! -d /etc/rancher-saas ]
  then
    echo "ERROR - Make sure /etc/rancher-saas exists on your local machine and is writable by you"
    exit 1
fi
export ENVIRONMENT_VALUES_FILE="./test/rancher-saas-ops/test-environment.yaml"
## Check if environment file exists
if [ ! -f $ENVIRONMENT_VALUES_FILE ]
  then
    echo "ERROR - ENVIRONMENT_VALUES_FILE does not exist"
    exit 1
fi

cp -rp ./deployments/kubernetes/helm/rancher-saas /etc/rancher-saas/helm
./build/package/rancher-saas-ops/webhook-scripts/update-rancher.bash $1 $2 $3 $4
rm -rf /etc/rancher-saas/helm