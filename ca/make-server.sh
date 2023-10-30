#!/bin/bash

export EASYRSA="/usr/local/ca"
export EASYRSA_PKI="/usr/local/ca/pki"
export EASYRSA_CERT_EXPIRE="1095"
export EASYRSA_CRL_DAYS="3"
export EASYRSA_KEY_SIZE="2048"
export EASYRSA_ALGO="rsa"
export EASYRSA_DIGEST="sha256"

cn="$1"
san="$2"

if [[ -z "$cn" ]]; then
  echo "Enter a CN:"
  read cn
fi

if [[ -z "$san" ]]; then
  echo "Enter a SAN string:"
  read san
fi

if [[ -z "$1" ]]; then
  echo "Request a server cert with CN: $cn and SAN: $san [y/n]?"
  read ans
else
  ans="y"
fi

if [[ "$ans" =~ ^[Yy][Ee]?[Ss]?$ ]]; then
  if [[ -n "$san" ]]; then
    echo "$cn" | $EASYRSA/easyrsa --subject-alt-name="${san}" gen-req ${cn} nopass
    echo "yes" | $EASYRSA/easyrsa --subject-alt-name="${san}" sign-req server ${cn}
  else
    echo "$cn" | $EASYRSA/easyrsa gen-req ${cn} nopass
    echo "yes" | $EASYRSA/easyrsa sign-req server ${cn}
  fi
fi
