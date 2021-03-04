#!/bin/bash

## Define varialbes for log output
if [ "$LOCAL" == "true" ]
  then
    OKLOGTARGET="/dev/stdout"
    ERRORLOGTARGET="/dev/stderr"
  else
    OKLOGTARGET="/proc/1/fd/1"
    ERRORLOGTARGET="/proc/1/fd/2"
fi

## Define functions
setDuration () {
  local ENDTIME=$(date +%s%3N)
  DURATION=$(echo "$ENDTIME - $STARTTIME" | bc -l)
}

logToStderr () {
  local STAGE="$1"
  local MESSAGE="$2"
  setDuration
  echo "time=\"$(date +%d.%m.%Y\ %H:%M:%S)\" level=ERROR job_id=$JOB_ID stage=$STAGE script_duration=$DURATION message=\"$MESSAGE\"" > $ERRORLOGTARGET
}

logToStdout () {
  local STAGE="$1"
  local LEVEL="$2"
  local MESSAGE="$3"
  setDuration
  echo "time=\"$(date +%d.%m.%Y\ %H:%M:%S)\" level=$LEVEL job_id=$JOB_ID stage=$STAGE script_duration=$DURATION message=\"$MESSAGE\"" > $OKLOGTARGET
}

webhookResponse () {
  local STATUS="$1"
  local MESSAGE="$2"
  setDuration
  echo "{ \"job_id\":$JOB_ID, \"status\":\"$STATUS\", \"duration\":$DURATION, \"message\":\"$MESSAGE\" }"
}