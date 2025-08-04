# Deploy Headscale on Kubernetes

Install Headscale on Kubernetes using kustomize, or just copy the yaml file(s) and edit it/them before applying it/them

# Deploying Headscale with kustomize | example

Create/Update kustomization.yaml file with your own values:

```yaml
# Create a kustomization.yaml file
cat <<EOF >./kustomization.yaml
---
# kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - github.com/jefferyb/k8s-headscale/base

### Update/Create your own ACL Policies
# https://github.com/juanfont/headscale/blob/main/docs/ref/acls.md
configMapGenerator:
  - name: headscale-acl-policy
    behavior: replace # Options: merge||replace
    files:
      - acl-policy.hujson=acl-policy.hujson

patches:
### Update Deployment env. variables that you want/need
  - patch: |-
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: headscale
      spec:
        template:
          spec:
            containers:
              - name: headscale
                env:
                  - name: HEADSCALE_SERVER_URL
                    value: headscale.example.com
                  - name: HEADSCALE_DNS_BASE_DOMAIN
                    value: base.example.com

# ### Use/Change from persistentVolumeClaim to hostPath
#   - patch: |-
#       $patch: delete
#       apiVersion: v1
#       kind: PersistentVolumeClaim
#       metadata:
#         name: headscale-volume-pvc

#   - target:
#       group: apps
#       version: v1
#       kind: Deployment
#       name: headscale
#     patch: |-
#       - op: replace
#         path: /spec/template/spec/volumes/2
#         value: 
#           name: headscale-volume
#           hostPath:
#             path: /opt/volumes/headscale/data

### Update ingress
  - patch: |-
      apiVersion: networking.k8s.io/v1
      kind: Ingress
      metadata:
        name: headscale
        annotations:
          cert-manager.io/cluster-issuer: lets-encrypt
      spec:
        ingressClassName: public
        rules:
          - host: headscale.example.com
            http:
              paths:
                - path: /
                  pathType: Prefix
                  backend:
                    service:
                      name: headscale
                      port:
                        name: http
        tls:
          - hosts:
            - headscale.example.com
            secretName: headscale-tls

EOF
```

```yaml
# Create a acl-policy.hujson file with your own ACL Policies
# https://github.com/juanfont/headscale/blob/main/docs/ref/acls.md
cat <<EOF >./acl-policy.hujson
{
  "groups": {
    "group:admin": ["my-username"],
  },

  // Allow all connections.
  // Match absolutely everything.
  // Comment this section out if you want to define specific restrictions.
  "acls": [
    {
      "action": "accept",
      "src": ["*"],
      "dst": ["*:*"]
    }
  ],

  // Allow group:admin to ssh to everything...
  "ssh": [
    {
      "action": "accept",
      "src": ["group:admin"],
      "dst": ["*"],
      "users": ["root", "my-username"]
    }
  ]
}
EOF
```

review the deployment with:

```bash
kubectl kustomize .
```

apply/deploy with run:

```bash
kubectl kustomize . | kubectl apply -f -
#  OR
kubectl apply --kustomize .
```

ref:
  * https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/
