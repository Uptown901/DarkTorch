#!/bin/bash

source global_vars.sh

# If there is already a server conf, then exit
conf=$(ls /etc/openvpn/server/vpn.conf 2>/dev/null)
[[ -n "$conf" ]] && exit

# Create firewall rules and allow ip forwarding
ifaces=($(nmcli -t -f device d | grep -v lo))
internal_iface=${ifaces[0]}
tun_iface="tun+"

service_network_net=$(ipcalc -n $(/sbin/ip addr show dev eth0 | grep "inet " | awk '{print $2}') | awk -F= '{print $2}')
service_network_prefix=$(ipcalc -p $(/sbin/ip addr show dev eth0 | grep "inet " | awk '{print $2}') | awk -F= '{print $2}')
service_network="${service_network_net}/${service_network_prefix}"

vpn_dhcp_network_net=$(grep "server [0-2][0-9][0-9]" "${script_home}/vpn.conf" | awk '{print $2}')
vpn_dhcp_network_prefix=$(ipcalc -p4s $(grep "server [0-2][0-9][0-9]" vpn.conf | awk '{print $2" "$3}') | awk -F= '{print $2}')
vpn_dhcp_network="${vpn_dhcp_network_net}/${vpn_dhcp_network_prefix}"

if [[ -n "$1" ]]; then
  client_count=5
  firewall-cmd --add-masquerade
  firewall-cmd --change-interface=${tun_iface} --zone=trusted
  firewall-cmd --add-service=dns --add-service=openvpn
  firewall-cmd --add-service=dns --zone=trusted
else
  firewall-cmd --add-masquerade --zone=internal
  firewall-cmd --change-interface=${internal_iface} --zone=internal
  firewall-cmd --change-interface=${tun_iface} --zone=drop
  firewall-cmd --add-service=dns --zone=drop
  firewall-cmd --add-service=dns --add-service=openvpn --zone=internal
  firewall-cmd --direct --add-rule ipv4 filter INPUT 0 -i ${tun_iface} -s ${vpn_dhcp_network} -j ACCEPT
  firewall-cmd --direct --add-rule ipv4 filter FORWARD 0 -i ${tun_iface} -s ${vpn_dhcp_network} -d ${service_network} -m conntrack --ctstate NEW -j ACCEPT
  firewall-cmd --direct --add-rule ipv4 filter FORWARD 0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
  firewall-cmd --direct --add-rule ipv4 filter FORWARD 0 -i ${tun_iface} -s ${vpn_dhcp_network} -d ${service_network} -p icmp -m state --state NEW,RELATED,ESTABLISHED -j ACCEPT
fi
firewall-cmd --runtime-to-permanent

# IP forwarding
sed -i 's/net.ipv4.ip_forward = 0/net.ipv4.ip_forward = 1/g' /etc/sysctl.conf
/sbin/sysctl -p

# Create CA
/bin/bash /usr/local/ca/make-ca.sh
cp /usr/local/ca/pki/ca.crt /etc/openvpn/server

# Server cert request
ip_check_urls=("https://icanhazip.com" "https://api.ipify.org" "https://ip.seeip.org")
pipaddr=$(curl -fsSL "${ip_check_urls[0]}")
[[ -z "$pipaddr" ]] && pipaddr=$(curl -fsSL "${ip_check_urls[1]}")
[[ -z "$pipaddr" ]] && pipaddr=$(curl -fsSL "${ip_check_urls[2]}")
/bin/bash /usr/local/ca/make-server.sh "$pipaddr" "IP:${pipaddr}"
cp /usr/local/ca/pki/issued/${pipaddr}.crt /etc/openvpn/server/server.crt
cp /usr/local/ca/pki/private/${pipaddr}.key /etc/openvpn/server/server.key

# DH and TA keys
/bin/bash /usr/local/ca/make-dh.sh
cp /usr/local/ca/pki/dh.pem /etc/openvpn/server

/sbin/openvpn --genkey --secret /usr/local/ca/pki/private/ta.key
cp /usr/local/ca/pki/private/ta.key /etc/openvpn/server

# Gen and copy crl
mkdir -p /etc/openvpn/server/jail/tmp
/bin/bash /usr/local/ca/make-crl.sh
cp /usr/local/ca/pki/crl.pem /etc/openvpn/server/jail
chown -R nobody:nobody /etc/openvpn/server/jail
chcon -R -t openvpn_etc_t /etc/openvpn/server/jail
ln -s /usr/local/ca/make-crl.sh /etc/cron.weekly/make-crl.sh
echo -e '#!/bin/bash\n/bin/cat /usr/local/ca/pki/crl.pem > /etc/openvpn/server/jail/crl.pem' > /etc/cron.daily/copy-crl.sh
chmod u+x /etc/cron.daily/copy-crl.sh

# Copy conf and start service
[[ -n "$1" ]] && sed -i 's/TLS-DHE-RSA-WITH-AES-128-GCM-SHA256/TLS-DHE-RSA-WITH-AES-128-CBC-SHA256/g' ${script_home}/vpn.conf
[[ -n "$1" ]] && sed -i 's/AES-256-GCM/AES-256-CBC/g' ${script_home}/vpn.conf
cp ${script_home}/vpn.conf /etc/openvpn/server
systemctl enable openvpn-server@vpn
systemctl start openvpn-server@vpn

# Setup and start logging service
mkdir -p /var/log/openvpn
touch /var/log/openvpn/vpn-status.log
touch /var/log/openvpn/vpn-server.log
touch /var/log/openvpn/vpn-history.log
chcon -R -t openvpn_var_log_t /var/log/openvpn
chmod 644 /var/log/openvpn/*.log
mv "${script_home}/openvpnstat.sh" "/etc/openvpn/server"
mv "${script_home}/openvpnstat@.service" "/etc/systemd/system"
echo ":syslogtag, isequal, \"VPN-STAT:\" /var/log/openvpn/vpn-history.log" > /etc/rsyslog.d/openvpn.conf
echo '& stop' >> /etc/rsyslog.d/openvpn.conf
echo '/var/log/openvpn/*.log {' > /etc/logrotate.d/openvpn.conf
echo '  rotate 7' >> /etc/logrotate.d/openvpn.conf
echo '  daily' >> /etc/logrotate.d/openvpn.conf
echo '  missingok' >> /etc/logrotate.d/openvpn.conf
echo '  notifempty' >> /etc/logrotate.d/openvpn.conf
echo '  create' >> /etc/logrotate.d/openvpn.conf
echo '  compress' >> /etc/logrotate.d/openvpn.conf
echo '  delaycompress' >> /etc/logrotate.d/openvpn.conf
echo '}' >> /etc/logrotate.d/openvpn.conf
systemctl restart rsyslog
systemctl enable openvpnstat@vpn
systemctl start openvpnstat@vpn

# SAS url for Azure Storage Account should have been passed in via custom data
sas_url=$(base64 -d /var/lib/waagent/CustomData)
sas="${sas_url##*\?}"
url="${sas_url%%\?*}"

# Create client accounts and QRs
client_dir="/etc/openvpn/client/configs"
mkdir -p "$client_dir"
for ((i=1; i<=client_count; i++)); do
  # Format the number to always be 2 digits
  num=$(printf "%02d" $i)

  # Create client cert and ovpn conf file
  /bin/bash /usr/local/ca/make-client.sh "u${num}"
  
  # Get SAS url for ovpn and for QR png
  qr_sas_url="${url}/u${num}.png?${sas}"
  config_sas_url="${url}/u${num}.ovpn?${sas}"

  # Create a QR code to download ovpn conf
  qrencode -o "${client_dir}/u${num}.png" "$config_sas_url"

  # Upload the QR code and the ovpn file to storage account
  curl -X PUT -T "${client_dir}/u${num}.ovpn" -H "x-ms-date: $(date -u)" -H "x-ms-blob-type: BlockBlob" "$config_sas_url"
  curl -X PUT -T "${client_dir}/u${num}.png" -H "x-ms-date: $(date -u)" -H "x-ms-blob-type: BlockBlob" "$qr_sas_url"
done
