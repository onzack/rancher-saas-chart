#!/bin/bash

# Define global variables
RANCHER_OVERALL_STATUS=1

# Define global functions
ECHO_RANCHER_OVERALL_STATUS () {
  echo "rancher_overall_health,instance=$RANCHER_INSTANCE_NAME value=$RANCHER_OVERALL_STATUS" >> $METRICSFILE
}

# Actual script
RANCHER_HEALTH=$(curl -s http://localhost/healthz)
if (( $? == "0" ))
  then
    if [[ $RANCHER_HEALTH == "ok" ]]
      then
        echo "OK - Metrics-Collector: Call Rancher health endpoint successful and the result is ok" > $OKLOGTARGET
        echo "rancher_health,instance=$RANCHER_INSTANCE_NAME value=1" >> $METRICSFILE
      else
        RANCHER_OVERALL_STATUS=0
        echo "ERROR - Metrics-Collector: Call Rancher health endpoint successful but the result was not ok" > $ERRORLOGTARGET
        echo "rancher_health,instance=$RANCHER_INSTANCE_NAME value=0" >> $METRICSFILE
    fi
  else
    RANCHER_OVERALL_STATUS=0
    echo "ERROR - Metrics-Collector: Call rancher health endpoint went wrong" > $ERRORLOGTARGET
    echo "rancher_health,instance=$RANCHER_INSTANCE_NAME value=0" >> $METRICSFILE
fi

ETCD_HEALTH=$(etcdctl -w json endpoint health)
if (( $? == "0" ))
  then
    if [ $(echo $ETCD_HEALTH | jq '.[] .health') ]
      then
        echo "OK - Metrics-Collector: Call ETCD health endpoint successful and the result is true" > $OKLOGTARGET
        echo "etcd_health,instance=$RANCHER_INSTANCE_NAME value=1" >> $METRICSFILE
      else
        RANCHER_OVERALL_STATUS=0
        echo "ERROR - Metrics-Collector: Call ETCD health endpoint successful but the result was not true" > $ERRORLOGTARGET
        echo "etcd_health,instance=$RANCHER_INSTANCE_NAME value=0" >> $METRICSFILE
    fi
    echo "etcd_health_response_speed,instance=$RANCHER_INSTANCE_NAME value=$(echo $ETCD_HEALTH | jq '.[] .took' | tr -d '"ms')" >> $METRICSFILE
  else
    RANCHER_OVERALL_STATUS=0
    echo "ERROR - Metrics-Collector: Call ETCD health endpoint went wrong" > $ERRORLOGTARGET
    echo "etcd_health,instance=$RANCHER_INSTANCE_NAME value=0" >> $METRICSFILE
fi

ETCD_STATUS=$(etcdctl -w json endpoint status)
if (( $? == "0" ))
  then
    echo "OK - Metrics-Collector: Call ETCD status endpoint successful" > $OKLOGTARGET
    echo "etcd_status,instance=$RANCHER_INSTANCE_NAME value=1" >> $METRICSFILE
    echo "etcd_status_dbSize,instance=$RANCHER_INSTANCE_NAME value=$(echo $ETCD_STATUS | jq '.[] .Status.dbSize')" >> $METRICSFILE
    echo "etcd_status_dbSizeInUse,instance=$RANCHER_INSTANCE_NAME value=$(echo $ETCD_STATUS | jq '.[] .Status.dbSizeInUse')" >> $METRICSFILE
  else
    RANCHER_OVERALL_STATUS=0
    echo "ERROR - Metrics-Collector: Call ETCD status endpoint went wrong" > $ERRORLOGTARGET
    echo "etcd_status,instance=$RANCHER_INSTANCE_NAME value=0" >> $METRICSFILE
fi

echo "INFO - Metrics-Collector: Start collecting metircs about Rancher and Rancher Guard filesystems" > $OKLOGTARGET
echo "rancher_fs_percentage,instance=$RANCHER_INSTANCE_NAME value=$(df | grep '/var/lib/rancher' | awk '{print $5}' | tr -d '%')" >> $METRICSFILE
echo "rancher_fs_size_kb,instance=$RANCHER_INSTANCE_NAME value=$(df | grep '/var/lib/rancher' | awk '{print $2}')" >> $METRICSFILE
echo "rancher_fs_used_kb,instance=$RANCHER_INSTANCE_NAME value=$(df | grep '/var/lib/rancher' | awk '{print $3}')" >> $METRICSFILE
echo "rancher_fs_available_kb,instance=$RANCHER_INSTANCE_NAME value=$(df | grep '/var/lib/rancher' | awk '{print $4}')" >> $METRICSFILE

echo "rancher_guard_fs_percentage,instance=$RANCHER_INSTANCE_NAME value=$(df | grep $MOUNTPATH | awk '{print $5}' | tr -d '%')" >> $METRICSFILE
echo "rancher_guard_fs_size_kb,instance=$RANCHER_INSTANCE_NAME value=$(df | grep $MOUNTPATH | awk '{print $2}')" >> $METRICSFILE
echo "rancher_guard_fs_used_kb,instance=$RANCHER_INSTANCE_NAME value=$(df | grep $MOUNTPATH | awk '{print $3}')" >> $METRICSFILE
echo "rancher_guard_fs_available_kb,instance=$RANCHER_INSTANCE_NAME value=$(df | grep $MOUNTPATH | awk '{print $4}')" >> $METRICSFILE
echo "INFO - Metrics-Collector: Finished collecting metircs about Rancher and Rancher Guard filesystems" > $OKLOGTARGET

ECHO_RANCHER_OVERALL_STATUS

exit 0