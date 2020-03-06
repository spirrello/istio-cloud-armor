#!/usr/bin/env bash


kubectl run nginx --image=nginx && k expose deploy/nginx --name nginx --type ClusterIP --port 80 --target-port 80
