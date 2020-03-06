#!/usr/bin/env bash

kubectl patch svc istio-ingressgateway -n istio-system --type json -p='[  {    "op": "add",    "path": "/metadata/annotations/cloud.google.com~1neg",    "value": "{\"ingress\": true}"  },  {    "op": "replace",    "path": "/spec/type",    "value": "NodePort"  },  {    "op": "remove",    "path": "/status"  },  {    "op": "add",    "path": "/metadata/annotations/beta.cloud.google.com~1backend-config",    "value": "{\"ports\": {\"80\":\"cloudarmor-staging-test\"}}"  }]'

kubectl run nginx --image=nginx && k expose deploy/nginx --name nginx --type ClusterIP --port 80 --target-port 80
