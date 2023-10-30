#!/bin/bash

export EASYRSA="/usr/local/ca"
export EASYRSA_PKI="${EASYRSA}/pki"

conf="${1}"
client_conf_dir="/etc/openvpn/client/configs"
mkdir -p "$client_conf_dir/revoked"

if [[ -z "$conf" ]]; then
  echo "Enter the client name without file extensions (i.e. vpn1-client10a):"
  read conf
fi

if [[ ! -f "${EASYRSA_PKI}/issued/${conf}.crt" ]]; then
  echo "Unable to locate cert for ${conf}..."
  exit 1
else
  echo "Revoking ${conf}..."
  if [[ "$2" == "batch" ]]; then
    echo "yes" | $EASYRSA/easyrsa revoke ${conf} certificateHold
  else
    $EASYRSA/easyrsa revoke ${conf} certificateHold
    /bin/bash $EASYRSA/make-crl.sh
  fi
  mv "${client_conf_dir}/${conf}.ovpn" "${client_conf_dir}/revoked"
fi
