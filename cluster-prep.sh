#!/usr/bin/env bash

set -e

PROJECT_NAME=$1
CLUSTER_NAME=$2
MASTER_CIDR=$3
ISTIO_VERSION=$4

if [ -z "$PROJECT_NAME" ]; then
  echo "Please provide the project"
  exit 1
fi

if [ -z "$CLUSTER_NAME" ]; then
  echo "Need a cluster name"
  exit 1
fi

if [ -z "$MASTER_CIDR" ]; then
  echo "Setting MASTER_CIDR to 172.16.0.0/16"
  MASTER_CIDR="172.16.0.0/16"
fi

if [ -z "$ISTIO_VERSION" ]; then
  ISTIO_VERSION="1.4.3"
  echo "Setting Istio to version $ISTIO_VERSION"
fi


kubectl create clusterrolebinding cluster-admin-binding \
    --clusterrole=cluster-admin \
    --user=$(gcloud config get-value core/account)

kubectl label namespace default istio-injection=enabled

cd istio-$ISTIO_VERSION

export PATH=$PWD/bin:$PATH

istioctl manifest apply --set profile=demo

#might need to run this in the case of timeouts for side car injection
TARGET_TAG=`gcloud compute instances list --project $PROJECT_NAME --format=json | /usr/bin/jq '.[].tags.items[0]'|head -1`
gcloud compute firewall-rules create allow-master-to-istiowebhook --allow=tcp:9443 --direction=INGRESS --enable-logging --source-ranges=$MASTER_CIDR --target-tags=$TARGET_TAG

INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
SECURE_INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')

echo "INGRESS_PORT=$INGRESS_PORT"

echo "SECURE_INGRESS_PORT=$SECURE_INGRESS_PORT"

echo "http://$INGRESS_HOST:$INGRESS_PORT"
