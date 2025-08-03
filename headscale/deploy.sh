#!/bin/bash
# This script deploys Headscale using Helm.

# Add the headscale helm repository
helm repo add gabe565 https://charts.gabe565.com

# Update your local helm chart repository cache
helm repo update

# Install headscale
# This will install headscale in the 'headscale' namespace, creating it if it doesn't exist.
# It uses the 'values.yaml' file for configuration.
helm install headscale gabe565/headscale \
  --namespace headscale \
  --create-namespace \
  -f values.yaml
