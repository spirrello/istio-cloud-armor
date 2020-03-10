#!/usr/bin/env bash

set -e

PROJECT_NAME=$1
CLUSTER_NAME=$2
ISTIO_VERSION="1.4.3"
FIREWALL_RULE="$CLUSTER_NAME-allow-master-to-istiowebhook"
SLEEP_TIME="120"

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


#check if cluster rolebinding exists
kubectl get clusterrolebinding cluster-admin-binding || CLUSTER_ROLE_STATUS=$?
if [ $CLUSTER_ROLE_STATUS > 0 ]; then
  echo "############## Creating clusterrolebinding ##############"
  kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=$(gcloud config get-value core/account)
else
  echo "############## clusterrolebinding already exists ##############"
fi

#label default namespace
kubectl label namespace default istio-injection=enabled || NS_LABEL_STATUS=$?
if [ $NS_LABEL_STATUS > 0 ]; then
  echo "############## default namespace is already labeled ##############"
else
  echo "############## default namespace now labeled ##############"
fi

#download istio
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$ISTIO_VERSION sh -

cd istio-$ISTIO_VERSION

export PATH=$PWD/bin:$PATH

echo "############## deploying default profile of istio ##############"
istioctl manifest apply --set profile=demo \
--set values.grafana.enabled=true --set values.kiali.enabled=true \
--set values.prometheus.enabled=true --set values.tracing.enabled=true

#deploy sample bookend app
kubectl apply -f samples/bookinfo/platform/kube/bookinfo.yaml

#might need to run this in the case of timeouts for side car injection

#fetch info then create firewall rule
CLUSTER_REGION=`gcloud container clusters list --filter "name:$CLUSTER_NAME" | grep -v NAME | awk '{print $2}'`
echo "CLUSTER_REGION: $CLUSTER_REGION"
MASTER_CIDR=`gcloud container clusters describe $CLUSTER_NAME --region $CLUSTER_REGION --format json | /usr/bin/jq -r .privateClusterConfig.masterIpv4CidrBlock`
echo "MASTER_CIDR: $MASTER_CIDR"
NODE_POOL=`gcloud container node-pools list --region $CLUSTER_REGION --cluster $CLUSTER_NAME | grep -v NAME | awk '{print $1}'`
echo "NODE_POOL: $NODE_POOL"
TARGET_TAG=`gcloud container node-pools describe $NODE_POOL --region us-central1 --cluster $CLUSTER_NAME --format json | jq -r .config.tags[0]`
echo "TARGET_TAG: $TARGET_TAG"
gcloud compute firewall-rules create $FIREWALL_RULE --allow=tcp:9443 --direction=INGRESS --enable-logging --source-ranges=$MASTER_CIDR --target-tags=$TARGET_TAG || FIREWALL_RULE_STATUS=$?

#open the app to outside traffic
kubectl apply -f samples/bookinfo/networking/bookinfo-gateway.yaml

echo "############## sleeping for $SLEEP_TIME seconds to allow for warm up.... ##############"

sleep $SLEEP_TIME

INGRESS_HOST=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].port}')
SECURE_INGRESS_PORT=$(kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="https")].port}')
GATEWAY_URL=$INGRESS_HOST:$INGRESS_PORT

echo "INGRESS_PORT=$INGRESS_PORT"

echo "SECURE_INGRESS_PORT=$SECURE_INGRESS_PORT"

echo "http://$GATEWAY_URL/productpage"
