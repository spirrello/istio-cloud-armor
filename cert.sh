#!/usr/bin/env bash

openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 \
-subj '/O=example Inc./CN=example.com' -keyout example.com.key -out example.com.crt

openssl req -out nginx.example.com.csr -newkey rsa:2048 -nodes \
-keyout nginx.example.com.key -subj "/CN=nginx.example.com/O=some organization"

openssl x509 -req -days 365 -CA example.com.crt -CAkey example.com.key \
-set_serial 0 -in nginx.example.com.csr -out nginx.example.com.crt
