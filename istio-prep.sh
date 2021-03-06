#!/usr/bin/env bash


#DEFAULTS
SECURITY_POLICY="cloudarmor-test"
PORT="80"
SLEEP_TIME="60"

echo "############## backing up istio-ingressgateway service ##############"
kubectl -n istio-system get svc istio-ingressgateway -o yaml > BACKUP-istio-ingressgateway.yaml

echo "############## applying cloud armor backend config ##############"
kubectl apply -f cloud-armor-backend.yaml

echo "############## creating istio service patch ##############"

# create patch to convert the service to type NodePort
cat <<EOF > istio-ingress-patch.json
[
  {
    "op": "add",
    "path": "/metadata/annotations/cloud.google.com~1neg",
    "value": "{\"ingress\": true}"
  },
  {
    "op": "add",
    "path": "/metadata/annotations/beta.cloud.google.com~1backend-config",
    "value": "{\"ports\": {\"$PORT\":\"$SECURITY_POLICY\"}}"
  },
  {
    "op": "add",
    "path": "/metadata/annotations/cloud.google.com~1app-protocols",
    "value": "{\"http2\": \"HTTP\", \"https\":\"HTTPS\"}"
  },
  {
    "op": "replace",
    "path": "/spec/type",
    "value": "NodePort"
  },
  {
    "op": "remove",
    "path": "/status"
  }
]
EOF

echo "############## generating certs ##############"
./cert.sh

echo "############## applying patch to istio gateway service ##############"
kubectl -n istio-system patch svc istio-ingressgateway \
    --type=json -p="$(cat istio-ingress-patch.json)" \
    --dry-run=true -o yaml | kubectl apply -f -

echo "############## apply gateway settings and set up telemetry ##############"
kubectl apply -f k8s/

echo "############## Script completed successfully but it might take a few minutes for the HTTP LB to be available. ##############"
