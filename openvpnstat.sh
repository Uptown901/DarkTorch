#!/bin/bash

log=$(cat "/var/log/openvpn/${1}-status.log")
logger -t "${1^^}-STAT" "$log"

while true; do
  sleep 5;
  log_=$(cat "/var/log/openvpn/${1}-status.log")
  if [[ "$log" != "$log_" ]]; then
    log="$log_"
    logger -t "${1^^}-STAT" "$log"
  fi
done
