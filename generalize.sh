#!/bin/bash

source global_vars.sh

# Don't keep bash history for the rest of the session
export HISTFILESIZE=0
export HISTSIZE=0

# Stop auditd for the rest of the session and turn off swap if applicable
service auditd stop
systemctl disable auditd
swapoff /mnt/resource/swapfile
### Put other services to disable here:
systemctl stop openvpn-server@vpn
systemctl disable openvpn-server@vpn
systemctl stop openvpnstat@vpn
systemctl disable openvpnstat@vpn
###

# Delete the swapfile, any CustomData passed by Azure as well as our internal CA
rm -f "${script_home}/install.sh"
rm -f /mnt/resource/swapfile
rm -f /var/lib/waagent/CustomData
rm -f /etc/pki/ca-trust/source/anchors/ca.pem
find /usr/local/scap/* -type d -prune -exec rm -r {} +
### Put other files to delete here:
rm -f /etc/openvpn/server/*.key
rm -f /etc/openvpn/server/*.crt
rm -f /etc/openpvn/server/*.pem
rm -f /etc/openvpn/server/*.txt
rm -f /etc/openvpn/server/vpn.conf
rm -f /etc/openvpn/server/jail/*
rm -f /etc/openvpn/server/jail/tmp/*
rm -f /etc/openvpn/client/configs/*
rm -f /etc/firewalld/direct.xm*
rm -rf /etc/rsyslog.d/openvpn.conf
rm -rf /etc/logrotate.d/openvpn.conf
rm -f /etc/cron.weekly/make-crl.sh
rm -f /etc/cron.daily/copy-crl.sh
rm -rf /var/log/openvpn
###

# Truncate all the logs
logs=($(find /var/log -type f))
for log in "${logs[@]}"; do
  cat /dev/null > "$log"
done

# Truncate all audits
audit_logs=($(find /var/log/audit -type f))
for audit_log in "${audit_logs[@]}"; do
  rm -f "$audit_log"
done

# Truncate all history files
homes=($(cat /etc/passwd | awk -F: '{print $6}'))
history_file=".bash_history"
for home in "${homes[@]}"; do
  if [[ -f "${home}/${history_file}" ]]; then
  cat /dev/null > "${home}/${history_file}"
  fi
done

# Deprovision the waagent
/sbin/waagent -deprovision+user

### Put firewall rules to disable here:
sed -i 's/net.ipv4.ip_forward = 1/net.ipv4.ip_forward = 0/g' /etc/sysctl.conf
/sbin/sysctl -p
if [[ -n "$1" ]]; then
  firewall-cmd --remove-masquerade --permanent
  firewall-cmd --change-interface=tun+ --zone=drop --permanent
  firewall-cmd --remove-service=dns --remove-service=openvpn --permanent
  firewall-cmd --remove-service=dns --zone=trusted --permanent
else
  firewall-cmd --remove-masquerade --zone=internal --permanent
  firewall-cmd --remove-service=dns --zone=internal --permanent
  firewall-cmd --remove-service=openvpn --zone=internal --permanent
  firewall-cmd --remove-service=dns --zone=drop
  ifaces=($(firewall-cmd --list-interfaces --zone=internal))
  for iface in ${ifaces[@]}; do
    firewall-cmd --change-interface=${iface} --zone=public --permanent
  done
fi
###

# Revert the waagent conf to not provision swap space
swap_size=$(grep 'ResourceDisk.SwapSizeMB' /etc/waagent.conf | awk -F= '{print $2}')
sed -i 's/ResourceDisk.EnableSwap=y/ResourceDisk.EnableSwap=n/g' /etc/waagent.conf
sed -i "s/ResourceDisk.SwapSizeMB=${swap_size}/ResourceDisk.SwapSizeMB=0/g" /etc/waagent.conf

# re-enable auditd so it will run on next boot and update ca trust to remove our internal CA
systemctl enable auditd
update-ca-trust enable
update-ca-trust extract
### Put other services to enable here:
systemctl restart rsyslog
###

# Add crontab entries to remove CentOS default repos on reboot and add init script
if [[ -z $(crontab -l | grep 'init_server.sh') ]]; then
  (crontab -l ; echo "@reboot /bin/bash ${script_home}/init_server.sh") | crontab -
fi
if [[ -z $(crontab -l | grep '/bin/rm -f /etc/yum.repos.d/CentOS*') ]]; then
  (crontab -l ; echo "@reboot /bin/rm -f /etc/yum.repos.d/CentOS*") | crontab -
fi

# Prompt for a shutdown, if "yes" clear root history a final time and shutdown
read -p "shutdown now?" shutdown
if [[ "${shutdown,,}" == "y" ]]; then
  history -w
  history -c && init 0
fi
