# Headscale on Kubernetes

This project provides a set of Kubernetes manifests and a deployment script to run [Headscale](https://github.com/juanfont/headscale), an open-source, self-hosted implementation of the Tailscale control server.

## Directory Structure

- `k8s/`: This directory contains all the Kubernetes manifest files, managed by Kustomize.
  - `00-namespace.yaml`: Creates the `headscale` namespace.
  - `01-service-account.yaml`: Creates the `headscale` service account.
  - `02-pvc.yaml`: Creates the PersistentVolumeClaim for data storage.
  - `03-service.yaml`: Exposes Headscale via a `LoadBalancer` service.
  - `04-configmap.yaml`: Contains the Headscale configuration.
  - `05-deployment.yaml`: Defines the Headscale deployment itself.
  - `kustomization.yaml`: The Kustomize file that ties all the manifests together.
- `deploy.sh`: A script to automate the deployment process.
- `GEMINI.md`: The instruction file for the Gemini assistant.

## How to Deploy

1.  **Ensure you have a running Kubernetes cluster** and `kubectl` is configured to connect to it.

2.  **Run the deployment script:**
    ```bash
    ./deploy.sh
    ```

The script will:
1.  Check for and install the `local-path-provisioner` if a `StorageClass` named `local-path` is not found.
2.  Apply all the Kubernetes manifests from the `k8s/` directory.
3.  Wait for the Headscale deployment to become ready.
4.  Retrieve the external IP address assigned to the `LoadBalancer` service.
5.  Update the Headscale deployment with the correct `HEADSCALE_SERVER_URL`.
6.  Wait for the final rollout to complete.

Upon successful completion, the script will print the URL for your Headscale server.

## :warning: Important Note on Storage

This configuration uses `local-path-provisioner`, which provides storage from a directory on a **single node**. This is simple for getting started, but it has a major drawback in a multi-node cluster:

- **If the Headscale pod is rescheduled to a different node, it will lose access to its data**, as the data is stored locally on the original node. This will result in a loss of your Headscale state (users, machines, etc.).

For a production or multi-node setup, you should replace `local-path-provisioner` with a proper distributed storage solution like:
- NFS
- Ceph (Rook)
- A cloud provider's block storage solution (e.g., EBS, GCE Persistent Disk)
