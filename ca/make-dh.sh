#!/bin/bash

export EASYRSA="/usr/local/ca"
export EASYRSA_PKI="${EASYRSA}/pki"

$EASYRSA/easyrsa gen-dh
