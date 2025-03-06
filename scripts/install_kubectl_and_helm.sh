#!/bin/bash

set -e  # Exit immediately if a command exits with a non-zero status

# Function to get the latest Helm version
get_latest_helm_version() {
    curl -s https://api.github.com/repos/helm/helm/releases/latest | grep '"tag_name"' | sed 's/.*"tag_name": "\(.*\)",/\1/'
}

# Function to get the latest kubectl version
get_latest_kubectl_version() {
    curl -Ls https://dl.k8s.io/release/stable.txt
}

# Function to install or update Helm
install_or_update_helm() {
    action=$1  # Argument will be either 'install' or 'update'

    # Echo dynamically based on the action
    echo "$action Helm..."
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    chmod 755 get_helm.sh
    ./get_helm.sh

}

# Function to install or update kubectl
install_or_update_kubectl() {
    action=$1  # Argument will be either 'install' or 'update'

    # Echo dynamically based on the action
    echo "$action kubectl..."
    curl -LO "https://dl.k8s.io/release/${LATEST_KUBECTL_VERSION}/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
}

# Checking Helm exists, if exists update Helm if required, else Install Helm if not installed.
echo "Checking Helm installation..."
if ! command -v helm &> /dev/null
then
    echo "Helm not found. Installing Helm..."
    LATEST_HELM_VERSION=$(get_latest_helm_version)
    echo "Installing Helm version: ${LATEST_HELM_VERSION}"
    install_or_update_helm "Install"
else
    # INSTALLED_HELM_VERSION=$(helm version --short | sed 's/Helm v//')
    INSTALLED_HELM_VERSION=$(helm version --short | sed 's/Helm v//;s/+.*//')
    # INSTALLED_HELM_VERSION=$(helm version --short | awk -F 'v' '{print $2}' | awk -F '+' '{print $1}')
    LATEST_HELM_VERSION=$(get_latest_helm_version)
    echo "Installed Helm version: ${INSTALLED_HELM_VERSION}"
    echo "Latest Helm version: ${LATEST_HELM_VERSION}"
    if [ "$INSTALLED_HELM_VERSION" != "$LATEST_HELM_VERSION" ]; then
        echo "Helm is outdated. Updating to latest version: ${LATEST_HELM_VERSION}"
        install_or_update_helm "Update"
    else
        echo "Helm is up-to-date."
    fi
fi

# Checking kubectl exists, if exists update kubectl if required, else Install kubectl if not installed.
echo "Checking kubectl installation..."
if ! command -v kubectl &> /dev/null
then
    echo "kubectl not found. Installing kubectl..."
    LATEST_KUBECTL_VERSION=$(get_latest_kubectl_version)
    echo "Installing kubectl version: ${LATEST_KUBECTL_VERSION}"
    install_or_update_kubectl "Install"
else
    INSTALLED_KUBECTL_VERSION=$(kubectl version --client --output=json | grep '"gitVersion"' | sed 's/.*"gitVersion": "\(.*\)",/\1/')
    LATEST_KUBECTL_VERSION=$(get_latest_kubectl_version)
    echo "Installed kubectl version: ${INSTALLED_KUBECTL_VERSION}"
    echo "Latest kubectl version: ${LATEST_KUBECTL_VERSION}"
    if [ "$INSTALLED_KUBECTL_VERSION" != "$LATEST_KUBECTL_VERSION" ]; then
        echo "kubectl is outdated. Updating to latest version: ${LATEST_KUBECTL_VERSION}"
        install_or_update_kubectl "Update"
    else
        echo "kubectl is up-to-date."
    fi
fi

# Helm and Kubectl Version
which helm && helm version
which kubectl && kubectl version --client

# Cleanup (Optional)
rm -f kubectl get_helm.sh
echo "kubectl and Helm installation completed successfully."