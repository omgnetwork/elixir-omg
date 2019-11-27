#!/bin/sh

retries=0

# Retries roughly every 5 seconds up to 5 minutes
while [ $retries -le 60 ];  do
  alarms=$(make get-alarms)
  status=$?
  echo ${alarms}
  if [ "$status" -eq "0" ]; then
    break;
  else
    retries=$(( $retries + 1 ))
    sleep 5
  fi
done
