#!/bin/sh

retries=0
status=1

# Retries roughly every 5 seconds up to 1 minute
while [ $retries -lt 12 ];  do
  alarms=$(make get-alarms)
  status=$?
  echo ${alarms}

  if [ "$status" -eq "0" ]; then
    exit 0
  fi

  retries=$(( ${retries} + 1 ))
  sleep 5
done

exit ${status}
