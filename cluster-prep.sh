#!/usr/bin/env bash

set -e
set -x

PROJECT_NAME=$1
CLUSTER_NAME=$2
ISTIO_VERSION="1.4.3"
FIREWALL_RULE="$CLUSTER_NAME-allow-master-to-istiowebhook"

if [ -z "$PROJECT_NAME" ]; then
  echo "Need a valid project name"
  exit 1
else
  PROJECT_NAME_RESULT=`gcloud projects list --filter="name:$PROJECT_NAME"`
  if [ -z "$PROJECT_NAME_RESULT" ]; then
     echo "$PROJECT_NAME is not a valid project"
     exit 1
  fi
fi

if [ -z "$CLUSTER_NAME" ]; then
  echo "Need a cluster name"
  exit 1
else
  CLUSTER_NAME_RESULT=`gcloud container clusters list --filter "name:$CLUSTER_NAME"`
  if [ -z "$CLUSTER_NAME_RESULT" ]; then
     echo "$CLUSTER_NAME is not a valid cluster"
     exit 1
  fi
fi



CLUSTER_ROLE_STATUS=`kubectl get clusterrolebinding | grep cluster-admin-binding`
if [ -z "$CLUSTER_ROLE_STATUS" ]; then
  echo "Creating clusterrolebinding"
  kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=$(gcloud config get-value core/account)
else
  echo "CLUSTER ROLE BINDING ALREADY EXISTS"
fi

NS_LABEL_STATUS=`kubectl get ns -l istio-injection | grep default`
if [ -z "$NS_LABEL_STATUS" ]; then
  echo "labling default name space"
  kubectl label namespace default istio-injection=enabled
else
  echo "default namespace is already labeled"
fi

set +x

cd istio-$ISTIO_VERSION

export PATH=$PWD/bin:$PATH

echo "deploying default profile of istio"
istioctl manifest apply --set profile=demo

#might need to run this in the case of timeouts for side car injection

#fetch info then create firewall rule
CLUSTER_REGION=`gcloud container clusters list --filter "name:$CLUSTER_NAME" | grep -v NAME | awk '{print $2}'`
echo "CLUSTER_REGION: $CLUSTER_REGION"
MASTER_CIDR=`gcloud container clusters describe $CLUSTER_NAME --region $CLUSTER_REGION --format json | /usr/bin/jq -r .privateClusterConfig.masterIpv4CidrBlock`
echo "MASTER_CIDR: $MASTER_CIDR"
TARGET_TAG=`gcloud compute instances list --project $PROJECT_NAME --format=json | /usr/bin/jq -r '.[].tags.items[0]'|head -1`
echo "TARGET_TAG: $TARGET_TAG"
gcloud compute firewall-rules create $FIREWALL_RULE --allow=tcp:9443 --direction=INGRESS --enable-logging --source-ranges=$MASTER_CIDR --target-tags=$TARGET_TAG

INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')
SECURE_INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')

echo "INGRESS_PORT=$INGRESS_PORT"

echo "SECURE_INGRESS_PORT=$SECURE_INGRESS_PORT"

echo "http://$INGRESS_HOST:$INGRESS_PORT"
