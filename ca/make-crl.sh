#!/bin/bash

export EASYRSA="/usr/local/ca"
export EASYRSA_PKI="/usr/local/ca/pki"

$EASYRSA/easyrsa gen-crl
