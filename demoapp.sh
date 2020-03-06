#!/usr/bin/env bash

# create demo app
kubectl run nginx --image=nginx && k expose deploy/nginx --name nginx --type ClusterIP --port 80 --target-port 80
