#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

# Install kubectl
echo "Installing kubectl..."
KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
kubectl version --client

# Install Helm
echo "Installing Helm..."
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 755 get_helm.sh  # 700 is too restrictive unless you want only the owner to execute
./get_helm.sh
helm version

# Cleanup (Optional)
rm -f kubectl get_helm.sh

echo "kubectl and Helm installation completed successfully."