#!/usr/bin/env bash

echo "############## backing up istio-ingressgateway service ##############"
kubectl -n istio-system get svc istio-ingressgateway -o yaml > BACKUP-istio-ingressgateway.yaml

echo "############## applying cloud armor backend config ##############"
kubectl apply -f cloud-armor-backend.yaml

echo "############## creating istio service patch ##############"
SECURITY_POLICY="cloudarmor-test"
PORT="80"
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

echo "############## applying patch to istio gateway service ##############"
kubectl -n istio-system patch svc istio-ingressgateway \
    --type=json -p="$(cat istio-ingress-patch.json)" \
    --dry-run=true -o yaml | kubectl apply -f -

echo "############## apply gateway settings and set up telemetry ##############"
kubectl apply -f k8s/
