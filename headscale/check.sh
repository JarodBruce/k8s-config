#!/bin/bash
# This script checks the status of the Headscale deployment.

echo "--- Checking all resources in the 'headscale' namespace ---"
kubectl get all,pvc -n headscale

echo ""
echo "--- Getting the External IP for the Headscale service ---"
EXTERNAL_IP=$(kubectl get svc headscale -n headscale -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

if [ -z "$EXTERNAL_IP" ]; then
  echo "External IP is not yet available. Please wait a few minutes and run this script again."
else
  echo "External IP: $EXTERNAL_IP"
  echo "Please update the 'server_url' in your 'values.yaml' to 'http://$EXTERNAL_IP:8080' and then run 'helm upgrade headscale gabe565/headscale -n headscale -f values.yaml' to apply the change."
fi
