# Using Istio on GKE with Cloud Armor

## This has only been tested in GKE without the Istio addon

### Requirements

- An existing Cloud Armor policy.  Using `cloudarmor-test` in this example.

- GKE cluster

### prep the cluster

`clulster-prep` script will make the following modifications:

- create a clusterbinding, `cluster-admin-binding`

- add a label to the default namespace, `istio-injection=enabled` for automatic sidecar injection

- install Istio v1.4.3 unless specified with the default profile along with several telemetry options

- installs the bookinfo demo app

- creates a GCP firewall rule, `$CLUSTER_NAME-allow-master-to-istiowebhook` for sidecar injection

```
./clulster-prep PROJECT CLUSTER_NAME ISTIO_VERSION

```

### prep Istio for Cloud Armor

`istio-prep` will make the following modifications:

- creates backend config for Cloud Armor *the security policy must exist ahead of time*

- patches istio ingress gateway service to be of type NodePort and applies backend config for Cloud Armor

- exposes telemetry apps in k8s/ and creates gateways
