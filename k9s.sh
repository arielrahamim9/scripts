#!/bin/bash
# To run this script directly from GitHub raw:
# curl -sSL https://raw.githubusercontent.com/arielrahamim9/scripts/refs/heads/main/k9s.sh | sh

# Configuration
CLUSTER_NAME="hyperspace-tfc-simulation"
REGION="eu-west-2"

# Function to check and install a utility
install_utility() {
    local name=$1
    local install_cmd=$2
    local check_cmd=${3:-"command -v $name"}
    
    if ! eval "$check_cmd" &> /dev/null; then
        echo "$name is not installed. Installing $name..."
        eval "$install_cmd"
    else
        echo "$name is already installed."
    fi
}

# Install required dependencies
echo "Checking and installing required dependencies..."
install_utility "curl/wget" "sudo apt-get install -y curl wget" "command -v curl && command -v wget"

# Install k9s
install_utility "k9s" "curl -sS https://webi.sh/k9s | sh && source ~/.config/envman/PATH.env"

# Install Helm
install_utility "helm" "curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"

# Install ArgoCD CLI
install_utility "argocd" 'curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64 && sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd && rm argocd-linux-amd64'

# Set up kubectl aliases
if ! grep -q "alias k=kubectl" ~/.bashrc; then
    echo "Setting up kubectl aliases..."
    echo 'alias k=kubectl' >> ~/.bashrc
    echo 'alias p="kubectl get pods"' >> ~/.bashrc
    echo "kubectl aliases added to .bashrc"
else
    echo "kubectl aliases already exist in .bashrc"
fi

# Configure kubectl context
echo "Configuring kubectl context..."
aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION

bash
clear
echo "Setup completed successfully!"
