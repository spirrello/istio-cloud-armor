#!/usr/bin/env bash

# create patch to convert the service to type NodePort
cat <<EOF > istio-ingress-patch.json
[
  {
    "op": "add",
    "path": "/metadata/annotations/cloud.google.com~1neg",
    "value": "{\"ingress\": true}"
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

# apply the patch
kubectl -n istio-system patch svc istio-ingressgateway \
    --type=json -p="$(cat istio-ingress-patch.json)" \
    --dry-run=true -o yaml | kubectl apply -f -