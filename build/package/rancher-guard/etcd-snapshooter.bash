#!/bin/bash

# Define global variables
ETCDCTL_API=3
HOUR=0
DAY=0
BACKUP_OVERALL_STATUS=1

# Define global functions
ECHO_BACKUP_OVERALL_STATUS () {
  echo "backup_overall_health,instance=$RANCHER_INSTANCE_NAME value=$BACKUP_OVERALL_STATUS" >> $METRICSFILE
}

# Actual script
HOUR=$(date +%k | tr -d "\ ")
DAY=$(date +%u)
if [ -f $BACKUPFILESPATH/snapshot_hour_$HOUR.db ]
  then
    rm $BACKUPFILESPATH/snapshot_hour_$HOUR.db
    echo "OK - ETCD-Snapshooter: Removed snapshot_hour_$HOUR.db etcd snapshot" > $OKLOGTARGET
fi
etcdctl snapshot save $BACKUPFILESPATH/snapshot_hour_$HOUR.db
if (( $? == "0" ))
  then
    echo "OK - ETCD-Snapshooter: Successfully created new snapshot_hour_$HOUR.db etcd snapshot" > $OKLOGTARGET
    chmod 644 $BACKUPFILESPATH/snapshot_hour_$HOUR.db
    echo "etcd_snapshot_hourly,instance=$RANCHER_INSTANCE_NAME value=1" >> $METRICSFILE
    if (( $HOUR == "0" ))
      then
        if [ -f $BACKUPFILESPATH/snapshot_day_$DAY.db ]
          then
	          rm $BACKUPFILESPATH/snapshot_day_$DAY.db
            echo "OK - ETCD-Snapshooter: Removed snapshot_day_$DAY.db etcd snapshot" > $OKLOGTARGET
        fi
        cp -p $BACKUPFILESPATH/snapshot_hour_$HOUR.db $BACKUPFILESPATH/snapshot_day_$DAY.db
        if (( $? == "0" ))
          then
	          echo "OK - ETCD-Snapshooter: Copied etcd snapshot snapshot_hour_$HOUR.db to snapshot_day_$DAY.db" > $OKLOGTARGET
            echo "etcd_snapshot_daily,instance=$RANCHER_INSTANCE_NAME value=1" >> $METRICSFILE
          else
            BACKUP_OVERALL_STATUS=0
	          echo "ERROR - ETCD-Snapshooter: Coping etcd snapshot snapshot_hour_$HOUR.db to snapshot_day_$DAY.db went wrong" > $ERRORLOGTARGET
            echo "etcd_snapshot_daily,instance=$RANCHER_INSTANCE_NAME value=0" >> $METRICSFILE
        fi
	      if (( $DAY == "7" ))
          then
	          i="8"
            while (( $i > 1))
	            do
		            a=$(($i - 1))
		            if [ -f $BACKUPFILESPATH/snapshot_weekly_$i.db ]
                  then
	                  rm $BACKUPFILESPATH/snapshot_weekly_$i.db
                    if (( $? == "0" ))
                      then
		                    echo "OK - ETCD-Snapshooter: Removed snapshot_weekly_$i.db etcd snapshot" > $OKLOGTARGET
                        mv $BACKUPFILESPATH/snapshot_weekly_$a.db $BACKUPFILESPATH/snapshot_weekly_$i.db
                        if (( $? == "0" ))
                          then
                            echo "OK - ETCD-Snapshooter: Renamed etcd snapshot snapshot_weekly_$a.db to snapshot_weekly_$i.db" > $OKLOGTARGET
                          else
                            BACKUP_OVERALL_STATUS=0
                            echo "ERROR - ETCD-Snapshooter: Renaming etcd snapshot snapshot_weekly_$a.db to snapshot_weekly_$i.db went wrong" > $ERRORLOGTARGET
                        fi
                      else
                        BACKUP_OVERALL_STATUS=0
                        echo "ERROR - ETCD-Snapshooter: Removing snapshot_weekly_$i.db etcd snapshot went wrong" > $ERRORLOGTARGET
                    fi
	              fi
		            i=$(($i - 1))
	          done
            if [ -f $BACKUPFILESPATH/snapshot_weekly_1.db ]
              then
                rm $BACKUPFILESPATH/snapshot_weekly_1.db
	              echo "OK - ETCD-Snapshooter: Removed snapshot_weekly_1.db etcd snapshot" > $OKLOGTARGET
            fi
            cp -p $BACKUPFILESPATH/snapshot_hour_$HOUR.db $BACKUPFILESPATH/snapshot_weekly_1.db
            if (( $? == "0" ))
              then
	              echo "OK - ETCD-Snapshooter: Copied etcd snapshot snapshot_hour_$HOUR.db to snapshot_weekly_1.db" > $OKLOGTARGET
                echo "etcd_snapshot_weekly,instance=$RANCHER_INSTANCE_NAME value=1" >> $METRICSFILE
	            else
                BACKUP_OVERALL_STATUS=0
	              echo "ERROR - ETCD-Snapshooter: Coping etcd snapshot snapshot_hour_$HOUR.db to snapshot_day_weekly_1.db went wrong" > $ERRORLOGTARGET
                echo "etcd_snapshot_weekly,instance=$RANCHER_INSTANCE_NAME value=0" >> $METRICSFILE
	          fi
        fi
    fi	
  else
    BACKUP_OVERALL_STATUS=0
    echo "ERROR - ETCD-Snapshooter: etcd snapshot went wrong" > $ERRORLOGTARGET
    echo "etcd_snapshot_hourly,instance=$RANCHER_INSTANCE_NAME value=0" >> $METRICSFILE
    if (( $HOUR == "0" ))
      then
        echo "ERROR - ETCD-Snapshooter: Coping etcd snapshot snapshot_hour_$HOUR.db to snapshot_day_$DAY.db went wrong, caused by error in hourly snapshot" > $ERRORLOGTARGET
        echo "etcd_snapshot_daily,instance=$RANCHER_INSTANCE_NAME value=0" >> $METRICSFILE
        if (( $DAY == "7" ))
          then
            echo "ERROR - ETCD-Snapshooter: Coping etcd snapshot snapshot_hour_$HOUR.db to snapshot_day_weekly_1.db went wrong, caused by error in hourly snapshot" > $ERRORLOGTARGET
            echo "etcd_snapshot_weekly,instance=$RANCHER_INSTANCE_NAME value=0" >> $METRICSFILE
	      fi
    fi
    exit 1
fi

ECHO_BACKUP_OVERALL_STATUS

exit 0
