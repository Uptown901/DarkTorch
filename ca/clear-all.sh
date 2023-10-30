#!/bin/bash

export EASYRSA="/usr/local/ca"
export EASYRSA_PKI="/usr/local/ca/pki"

echo "yes" | $EASYRSA/easyrsa clean-all

/bin/rm -rf "$EASYRSA_PKI"
