#!/bin/bash

source global_vars.sh
project="VpnImage"

# Add crontab entries to remove CentOS default repos on reboot and add init script
if [[ -z $(crontab -l | grep 'init_server.sh') ]]; then
  (crontab -l ; echo "@reboot /bin/bash ${script_home}/init_server.sh $1" | xargs) | crontab -
fi
if [[ -z $(crontab -l | grep '/bin/rm -f /etc/yum.repos.d/CentOS*') ]]; then
  (crontab -l ; echo "@reboot /bin/rm -f /etc/yum.repos.d/CentOS*") | crontab -
fi

echo 'cd ~' >> /root/.bashrc
### Add other setup commands / scripts here:
pat=$(base64 -d /var/lib/waagent/CustomData)

curl -fskSL -o "${script_home}/install.zip" "https://${pat}@dev.s2va.us/Workloads/${project}/archive/refs/heads/main.zip"

[[ ! -f "${script_home}/install.zip" ]] && echo "install.zip not found!" && exit 1

unzip "${script_home}/install.zip"

rm -f "${script_home}/${project}-main/install.sh" || exit 1
rm -f "${script_home}/${project}-main/README.md" || exit 1

# Remove default repos and add the Azure ones
rm -f /etc/yum.repos.d/CentOS*
cp "${script_home}/centos.repo" /etc/yum.repos.d
yum clean all

yum -y install openvpn dnsmasq qrencode unzip

systemctl enable dnsmasq

mv "${script_home}/${project}-main/ca" /usr/local
chmod u+x /usr/local/ca/*.sh
chcon -R -t usr_t /usr/local/ca

mv ${script_home}/${project}-main/* ${script_home}
chmod u+x ${script_home}/*.sh

rm -rf ${script_home}/${project}-main
rm -f ${script_home}/install.zip

yum -y update
###
