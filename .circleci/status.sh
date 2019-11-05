#!/bin/sh

while true;  do
  alarms=$(make get-alarms)
  status=$?
  echo ${alarms}
  if [ "$status" -eq "0" ]; then
    break;
  else
    sleep 5
  fi
done
