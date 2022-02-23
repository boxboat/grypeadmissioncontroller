# grypy

This runs [grype](https://github.com/anchore/grype) as an admission controller. There is a `configmap` which allows you to specify a grype config file which is where most or all of the customization should take place. Everything else is a simple "accept this pod JSON, scan it" operation. Grype will use caching (by default) to avoid murdering the CVE database, but this can be disabled for air-gapped environments. There is documentation on editing the `configmap` for adding whitelists in the `configmap`.

## I need help! I can't get my pods to run after installing this!

We would be glad to help you fix your applications and help with kubernetes in general! You can [contact us here](https://boxboat.com/company/contact-us/). Please do not open issues with your specific applications problems.

## Why?

Shift-left the security scanning portions. This allows for a more natural workflow with gitops/helm charts being able to grab pods from their respective registries without giving up the security scanning which might be baked into your own registry.

## About Those Caches...

Grype will cache the vulernability DB _but not the results of a scan_. This is because `tags` are not immutable. You can increase the performance of the scanning by adding more `replicas` to the deployment. There is a small delay in starting new grype pods as they download the vulnerability database.

## Installation

Why not use helm? Because the user is required to generate unique certificates for themselves and we cannot execute the openssl commands from helm.

Set `GRYPE_VERSION` in your env to specify which version of the container to deploy, or it will default to `latest`.

Set `IMAGEPULLSECRET` in your env to the name of the imagePullSecret you want to use. Leave this blank if not needed. Note that we will not generate this for you - you are responsible for your own authentication to your registry.

Run `gen_certs.sh` to generate your *unique* certificates. Then `kubectl apply -f manifest.yaml`. 

After the grypy pod is running, run `kubectl patch validatingwebhookconfigurations grypy --patch-file webhookpatch.yaml` which enables enforcement.

You may test enforcement with `kubectl apply -f app_ok.yaml` which should pass, and `kubectl apply -f app_wrong.yaml` which should fail.

## Building

All contributions need to comply with the Developer Certificate of Origin Version 1.1 (see DCO.txt) and the Apache License 2.0 (see LICENSE).

### Run it locally

We're big fans of [Rancher Desktop](https://rancherdesktop.io/) for our local kubernetes clusters. Please test your changes locally before contributing or before pushing your changes into your environment.

### go

`rm go.* ; go mod init grypy ; go mod tidy; go mod vendor` and then check your changes in.

### Manifests

Just check them into the repo - skip regenerating the go. If you edit the `configmap` on a running cluster, you should kill the pod and let it respawn.

## Troubleshooting

### Basic

grype is setup to complain to STDOUT, so each container it scans and admits (or denies) will have it's output captured in the usual places. The logs directory is also present but not a PVC so if things get full up in the cluster, just kill the pod. If logging attestation is required, have your logging system look in `/tmp/logs` in the pod.

### Grype keeps murdering my builds in X namespace spawned by Y runner

See `ValidatingWebhookConfiguration` and add your namespace to the list of whitelisted namespaces. By default this is only `kube-system`.
