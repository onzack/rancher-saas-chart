#!/bin/bash

STARTTIME=$(date +%s.%N)

# Define global variables
DURATION=0
RANCHER_GUARD_CONFIG=$BACKUPFILESPATH/rancher-guard.config

# Define global functions
ECHO_DURATION () {
  ENDTIME=$(date +%s.%N)
  DURATION=$(echo "$ENDTIME - $STARTTIME" | bc -l | sed -e 's/^\./0./')
  echo "script_duration_seconds,instance=$RANCHER_INSTANCE_NAME value=$DURATION" >> $METRICSFILE
}

# Actual script
if [ -f $METRICSFILE ]
then
  echo "INFO - Rancher-Guard: Remove old metrics file"
  rm $METRICSFILE
fi
echo "INFO - Rancher-Guard: Start scheduled Rancher-Guard run" > $OKLOGTARGET
source $RANCHER_GUARD_CONFIG
echo "INFO - Rancher-Guard: Start collectig metrics" > $OKLOGTARGET
/usr/local/bin/collect-metrics.bash
if (( $? != "0" ))
  then
    echo "ERROR - Rancher-Guard: Collecting metrics went wrong" > $ERRORLOGTARGET
  else
    echo "OK - Rancher-Guard: Collecting metrics was successful" > $OKLOGTARGET
fi
if [ "$HOURLY_SNAPSHOT" == true ]
  then
    echo "INFO - Rancher-Guard: Start etcd-snapshooter" > $OKLOGTARGET
	   /usr/local/bin/etcd-snapshooter.bash
    if (( $? != "0" ))
      then
        echo "ERROR - Rancher-Guard: The etcd-snapshooter script went wrong" > $ERRORLOGTARGET
	     else
        echo "OK - Rancher-Guard: The etcd-snapsooter was successful" > $OKLOGTARGET
    fi
fi
ECHO_DURATION
echo "INFO - Rancher-Guard: Printing metrics file:"
cat $METRICSFILE > $OKLOGTARGET
echo "INFO - Rancher-Guard: Uploading metrics file"
curl -i -XPOST "$INFLUXDB_URL:$INFLUXDB_PORT/write?db=$INFLUXDB_NAME&u=$INFLUXDB_USER&p=$INFLUXDB_PW" --data-binary @$METRICSFILE
if (( $? == "0" ))
  then
    echo "OK - Rancher-Guard: Uploading metrics successful" > $OKLOGTARGET
  else
    echo "ERROR - Rancher-Guard: Uploading metrics went wrong" > $ERRORLOGTARGET
fi