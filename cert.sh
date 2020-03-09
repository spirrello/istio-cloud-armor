#!/usr/bin/env bash

#CA CERT
ORG="example"
CN="example.com"
CA_CERT="ca-cert.crt"
CA_KEY="ca.key"

#CERT REQUEST
CSR="nginx.example.com.csr"
CERT_CN="nginx.example.com"
CERT_KEY="nginx.example.com.key"
CERT_NAME="nginx.example.com.crt"
CERT_ORG="SOME ORG"
K8S_SECRET="testsecret-tls"

openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 \
-subj "/O=$ORG Inc./CN=$CN" -keyout $CA_KEY -out $CA_CERT

openssl req -out $CSR -newkey rsa:2048 -nodes \
-keyout $CERT_KEY -subj "/CN=$CERT_CN/O=$CERT_ORG"

openssl x509 -req -days 365 -CA $CA_CERT -CAkey $CA_KEY \
-set_serial 0 -in $CSR -out $CERT_NAME

kubectl create secret tls $K8S_SECRET --cert=$CERT_NAME --key=$CERT_KEY
