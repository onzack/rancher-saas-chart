#!/bin/bash

# Prerequisites
# This script needs this environment variables to be set
# - RANCHER_INSTANCE_NAME
# - INFLUXDB_URL
# - INFLUXDB_PORT
# - INFLUXDB_NAME
# - INFLUXDB_USER
# - INFLUXDB_PW
# - OKLOGTARGET
# - ERRORLOGTARGET
# - METRICSFILE
# - MOUNTPATH
# - BACKUPFILESPATH

# Check environment variables
if [[ -z $RANCHER_INSTANCE_NAME ]]
  then
    echo "ERROR - Scheduler: RANCHER_INSTANCE_NAME environment variable is not set" > $ERRORLOGTARGET
    exit 1
fi

if [[ -z $INFLUXDB_URL ]]
  then
    echo "ERROR - Scheduler: INFLUXDB_URL environment variable is not set" > $ERRORLOGTARGET
    exit 1
fi

if [[ -z $INFLUXDB_PORT ]]
  then
    echo "ERROR - Scheduler: INFLUXDB_PORT environment variable is not set" > $ERRORLOGTARGET
    exit 1
fi

if [[ -z $INFLUXDB_NAME ]]
  then
    echo "ERROR - Scheduler: INFLUXDB_NAME environment variable is not set" > $ERRORLOGTARGET
    exit 1
fi

if [[ -z $INFLUXDB_USER ]]
  then
    echo "ERROR - Scheduler: INFLUXDB_USER environment variable is not set" > $ERRORLOGTARGET
    exit 1
fi

if [[ -z $INFLUXDB_PW ]]
  then
    echo "ERROR - Scheduler: INFLUXDB_PW environment variable is not set" > $ERRORLOGTARGET
    exit 1
fi

if [[ -z $OKLOGTARGET ]]
  then
    echo "ERROR - Scheduler: OKLOGTARGET environment variable is not set" > $ERRORLOGTARGET
    exit 1
fi

if [[ -z $ERRORLOGTARGET ]]
  then
    echo "ERROR - Scheduler: ERRORLOGTARGET environment variable is not set" > $ERRORLOGTARGET
    exit 1
fi

if [[ -z $METRICSFILE ]]
  then
    echo "ERROR - Scheduler: METRICSFILE environment variable is not set" > $ERRORLOGTARGET
    exit 1
fi

if [[ -z $MOUNTPATH ]]
  then
    echo "ERROR - Scheduler: MOUNTPATH environment variable is not set" > $ERRORLOGTARGET
    exit 1
fi

if [[ -z $BACKUPFILESPATH ]]
  then
    echo "ERROR - Scheduler: BACKUPFILESPATH environment variable is not set" > $ERRORLOGTARGET
    exit 1
fi

# Define global variables
RANCHER_GUARD_CONFIG=$BACKUPFILESPATH/rancher-guard.config
CURRENT_MINUTE=0
SLEEPDURATION=120

# Enable extglob for minute calculation
shopt -s extglob

# Actual script
if [ -f $RANCHER_GUARD_CONFIG ]
  then
    echo "OK - Scheduler: $RANCHER_GUARD_CONFIG already exists" > $OKLOGTARGET
  else
    echo "HOURLY_SNAPSHOT=false" > $RANCHER_GUARD_CONFIG
    if (( $? != "0" ))
      then
        echo "ERROR - Scheduler: Creating $RANCHER_GUARD_CONFIG went wrong" > $ERRORLOGTARGET
        exit 1
    fi
fi

echo "INFO - Scheduler: Sleep 60 seconds to allow Rancher to start properly" > $OKLOGTARGET
sleep 60

while true
  do
    CURRENT_MINUTE=$(date +%M)
    CALCULABLE_MINUTE=${CURRENT_MINUTE#+(0)}
    echo "DEBUG - Scheduler: Variable CURRENT_MINUTE has value: $CURRENT_MINUTE" > $OKLOGTARGET
    echo "DEBUG - Scheduler: Variable CALCULABLE_MINUTE has value: $CALCULABLE_MINUTE" > $OKLOGTARGET
    if (( $CALCULABLE_MINUTE < "2" ))
      then
        echo "HOURLY_SNAPSHOT=true" > $RANCHER_GUARD_CONFIG
      else
        echo "HOURLY_SNAPSHOT=false" > $RANCHER_GUARD_CONFIG
    fi
    echo "INFO - Scheduler: Start Rancher-Guard sript in background" > $OKLOGTARGET
  	/usr/local/bin/rancher-guard.bash &
    echo "INFO - Scheduler: $RANCHER_GUARD_CONFIG contains: $(cat $RANCHER_GUARD_CONFIG)" > $OKLOGTARGET
    echo "INFO - Scheduler: Finished scheduler run, see you in $SLEEPDURATION seconds" > $OKLOGTARGET
    sleep $SLEEPDURATION
done