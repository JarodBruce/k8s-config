#!/bin/bash
set -euo pipefail

# --- Configuration ---
NAMESPACE="headscale"
PROVISIONER_URL="https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml"
# This is a placeholder. The script will replace it with the actual external IP.
PLACEHOLDER_URL="http://placeholder.local"

# --- Helper Functions ---
info() {
    echo "[INFO] $1"
}

error() {
    echo "[ERROR] $1" >&2
    exit 1
}

# --- Main Logic ---

# 1. Check for and install local-path-provisioner if not present
info "Checking for local-path StorageClass..."
if ! kubectl get storageclass local-path >/dev/null 2>&1; then
    info "local-path-provisioner not found. Installing..."
    kubectl apply -f "$PROVISIONER_URL"
    info "local-path-provisioner installed."
else
    info "local-path StorageClass already exists."
fi

# 2. Create namespace if it doesn't exist
info "Ensuring namespace '$NAMESPACE' exists..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# 3. Define the Kubernetes manifest using a here-document
info "Applying Headscale manifest..."
cat <<EOF | kubectl apply -n "$NAMESPACE" -f -
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: headscale
---
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: headscale-main
spec:
  accessModes:
    - "ReadWriteOnce"
  storageClassName: local-path
  resources:
    requests:
      storage: "1Gi"
---
apiVersion: v1
kind: Service
metadata:
  name: headscale
spec:
  type: LoadBalancer
  ports:
    - name: http
      port: 8080
      targetPort: 8080
      protocol: TCP
    - name: metrics
      port: 9090
      targetPort: 9090
      protocol: TCP
  selector:
    app: headscale
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: headscale
spec:
  replicas: 1
  selector:
    matchLabels:
      app: headscale
  template:
    metadata:
      labels:
        app: headscale
    spec:
      serviceAccountName: headscale
      securityContext:
        fsGroup: 1000
        runAsUser: 1000
        runAsGroup: 1000
      initContainers:
        - name: init-permissions
          image: alpine:3.18
          securityContext:
            runAsUser: 0 # Run as root
          command: ["/bin/sh", "-c"]
          args:
            - |
              set -e
              echo "Initializing volume permissions and config..."
              mkdir -p /data/etc
              cat <<'EOF' > /data/etc/config.yaml
              # This config file contains all required keys for Headscale to pass startup validation.
              # The actual values are overridden by environment variables at runtime.
              server_url: http://placeholder.local:8080
              listen_addr: 0.0.0.0:8080
              metrics_listen_addr: 0.0.0.0:9090
              private_key_path: /data/private.key
              noise:
                private_key_path: /data/noise_private.key
              database:
                type: sqlite3
                sqlite:
                  path: /data/db.sqlite
              ip_prefixes:
                - 100.64.0.0/10
              EOF
              # Change ownership to the non-root user that the main container will use
              chown -R 1000:1000 /data
              echo "Permissions set."
          volumeMounts:
            - name: data
              mountPath: /data
      containers:
        - name: headscale
          image: headscale/headscale:v0.25.0
          imagePullPolicy: IfNotPresent
          command:
            - "headscale"
          args:
            - "serve"
            - "--config"
            - "/data/etc/config.yaml"
          env:
            # Environment variables will override the values in the config file.
            - name: HEADSCALE_SERVER_URL
              value: "${PLACEHOLDER_URL}"
            - name: HEADSCALE_IP_PREFIXES
              value: "100.64.0.0/10, fd7a:115c:a1e0::/48"
          ports:
            - name: http
              containerPort: 8080
            - name: metrics
              containerPort: 9090
          volumeMounts:
            - name: data
              mountPath: /data
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: headscale-main
EOF

info "Manifest applied."

# 4. Wait for the initial deployment to be ready
info "Waiting for Headscale deployment to complete..."
kubectl rollout status deployment/headscale -n "$NAMESPACE" --timeout=5m

# 5. Get the External IP
info "Waiting for External IP..."
EXTERNAL_IP=""
for i in {1..60}; do
    EXTERNAL_IP=$(kubectl get svc headscale -n "$NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
    if [[ -n "$EXTERNAL_IP" ]]; then
        break
    fi
    info "Still waiting for External IP... ($i/60)"
    sleep 5
done

if [[ -z "$EXTERNAL_IP" ]]; then
    error "Failed to get External IP after 5 minutes."
fi

SERVER_URL="http://${EXTERNAL_IP}:8080"
info "External IP found: $EXTERNAL_IP"
info "Final Server URL: $SERVER_URL"

# 6. Update the deployment with the correct Server URL and trigger a new rollout
info "Updating deployment with the final Server URL..."
kubectl set env deployment/headscale -n "$NAMESPACE" "HEADSCALE_SERVER_URL=${SERVER_URL}"

info "Waiting for the final rollout to complete..."
kubectl rollout status deployment/headscale -n "$NAMESPACE" --timeout=5m

info "✅ Deployment successful!"
info "Your Headscale server is running at: ${SERVER_URL}"
