#!/bin/bash

export EASYRSA="/usr/local/ca"
export EASYRSA_PKI="/usr/local/ca/pki"
export EASYRSA_CERT_EXPIRE="395"
export EASYRSA_KEY_SIZE="2048"
export EASYRSA_ALGO="rsa"
export EASYRSA_DIGEST="sha256"

cn="$1"

if [[ -z "$cn" ]]; then
  echo "Enter a CN:"
  read cn
fi

ip_check_urls=("https://icanhazip.com" "https://api.ipify.org" "https://ip.seeip.org")

client_dir="/etc/openvpn/client/configs"
conf="/etc/openvpn/server/vpn.conf"
remote_host=$(curl -fsSL "${ip_check_urls[0]}")
remote_port=1194
remote_protocol="udp"
remote_cipher=
remote_tls_cipher=
remote_auth=

# Try a few times to determine public IP
if [[ -z "$remote_host" ]]; then
  i=0
  while [[ $i < "${#ip_check_urls[@]}" ]]; do
    sleep 2
    remote_host=$(curl -fsSL "${ip_check_urls[$i]}")
    i=$((i+1))
    [[ -n "$remote_host" ]] && break
  done
  [[ -z "$remote_host" ]] && echo "Unable to determine public IP Address" && exit 1
fi

if [[ -f "${conf}" ]]; then
  remote_protocol=$(grep "^proto" $conf | awk '{print $2}')
  remote_cipher=$(grep "^cipher" $conf | awk '{print $2}')
  remote_tls_cipher=$(grep "^tls-cipher" $conf | awk '{print $2}')
  remote_auth=$(grep "^auth" $conf | awk '{print $2}')
else
  echo "File: ${conf} is not accessible."
  exit 1
fi

# Build client certificate
$EASYRSA/easyrsa build-client-full "$cn" nopass 1>/dev/null
[[ $? -ne 0 ]] && "Error creating ${cn}" && exit 1

# Create ovpn conf file
mkdir -p "$client_dir"
client_config="${client_dir}/${cn}.ovpn"

# Add settings
echo "client" > "$client_config"
echo "dev tun" >> "$client_config"
echo "remote $remote_host $remote_port" >> "$client_config"
echo "proto $remote_protocol" >> "$client_config"
echo "cipher $remote_cipher" >> "$client_config"
echo "tls-cipher $remote_tls_cipher" >> "$client_config"
echo "auth $remote_auth" >> "$client_config"
echo "keepalive 10 60" >> "$client_config"
echo "lport 0" >> "$client_config"
echo "remote-cert-tls server" >> "$client_config"
[[ -z "$2" ]] && echo "log ${cn}.log" >> "$client_config"
echo "key-direction 1" >> "$client_config"
echo "comp-lzo no" >> "$client_config"

# Add keys and certs
echo '<ca>' >> "$client_config"
cat "${EASYRSA_PKI}/ca.crt" >> "$client_config"
echo '</ca>' >> "$client_config"

echo '<cert>' >> "$client_config"
sed -n '/BEGIN.*-/,/END.*-/p' "${EASYRSA_PKI}/issued/${cn}.crt" >> "$client_config"
echo '</cert>' >> "$client_config"

echo '<key>' >> "$client_config"
cat "${EASYRSA_PKI}/private/${cn}.key" >> "$client_config"
echo '</key>' >> "$client_config"

echo '<tls-auth>' >> "$client_config"
cat "${EASYRSA_PKI}/private/ta.key" >> "$client_config"
echo '</tls-auth>' >> "$client_config"
