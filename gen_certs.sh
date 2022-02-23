#!/bin/bash

while getopts ":h" option; do
   case $option in
      \?)
         echo "This script does not accept any options."
         echo "See the README at https://github.com/boxboat/grypeadmissioncontroller#installation for help."
         exit;;
   esac
done

set -o errexit
set -o nounset
set -o pipefail

# figure out if GRYPE_VERSION is set and set it if not
if [ -z ${GRYPE_VERSION+x} ]; then export GRYPE_VERSION=latest; fi

# figure out if the user specified an IMGPULLSECRET
if [ ! -z ${IMAGEPULLSECRET+x} ]; then export CONSTRUCTED_SECRET="imagePullSecrets:
        - name: ${IMAGEPULLSECRET}"; fi # Don't change the whitespace here because bash is dumb

# create private key for custom self signed CA
openssl genrsa -out certs/ca.key 2048

# gen a CA cert with that priv key
openssl req -new -x509 -key certs/ca.key -out certs/ca.crt -config certs/ca_config.txt

# create the priv key for our grypy server
openssl genrsa -out certs/grypy-key.pem 2048

# create a CSR from our key file and priv key
openssl req -new -key certs/grypy-key.pem -subj "/CN=grypy.default.svc" -out grypy.csr #-config certs/grypy_config.txt

# create the cert signing the CSR
openssl x509 -req -in grypy.csr -CA certs/ca.crt -CAkey certs/ca.key -CAcreateserial -out certs/grypy-crt.pem -extfile certs/grypy_config.txt

# inject the CA
export CA_BUNDLE=$(cat certs/ca.crt | base64 | tr -d '\n')
cat _manifest_.yaml | envsubst > manifest.yaml
echo --- >> manifest.yaml
kubectl create secret generic grypy -n default --from-file=key.pem=certs/grypy-key.pem --from-file=cert.pem=certs/grypy-crt.pem -o yaml --dry-run=client >> manifest.yaml

echo "To install the grype validating webhook run:"
echo "   kubectl apply -f manifest.yaml"
echo "After the grypy pod is running, set the webhook to Fail rather than Ignore:"
echo "   kubectl patch validatingwebhookconfigurations grypy --patch-file webhookpatch.yaml"
