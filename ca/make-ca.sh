#!/bin/bash

export EASYRSA="/usr/local/ca"
export EASYRSA_PKI="${EASYRSA}/pki"

$EASYRSA/easyrsa clean-all
echo "VPN-CA" | $EASYRSA/easyrsa build-ca nopass
