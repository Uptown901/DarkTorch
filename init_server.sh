#!/bin/bash

source global_vars.sh

# Hold off on doing anything until the waagent has successfully set the hostname
while [[ $(hostname) == "localhost" || $(hostname) == "localhost.localdomain" ]]; do
  sleep 10
done

# Setup swap space (if we have a resource disk - we should for prod workloads)
/bin/bash "${script_home}/az_temp_disk.sh"

# Enable all swap space
/sbin/swapon -a

#### VPN Server uses it's own CA and does not need to trust the service CA ####

# Get the CA certificate and add it to trusted roots
#ca=$(curl -fksSL "https://${ca_hostname}:8443/ca.crt")
#while [[ -z "$ca" ]]; do
#  sleep 10
#  ca=$(curl -fksSL "https://${ca_hostname}:8443/ca.crt")
#done
#
#echo "$ca" > /etc/pki/ca-trust/source/anchors/ca.pem
#
#update-ca-trust enable
#update-ca-trust extract

####

### Add additional scripts / commands here:
/bin/bash "${script_home}/init_vpn.sh" "$1"
###

# Remove crontab entry for this script
(crontab -l | grep -v $(basename "$0")) | crontab -
