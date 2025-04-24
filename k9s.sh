#!/bin/bash
set -e

# To run this script directly from GitHub raw:
# curl -sSL https://raw.githubusercontent.com/arielrahamim9/scripts/refs/heads/main/k9s.sh | bash

# Configuration
CLUSTER_NAME="hyperspace-tfc-simulation"
REGION="eu-west-2"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Logging functions
log_success() { echo -e "${GREEN}✓ $1${NC}"; }
log_error() { echo -e "${RED}✗ $1${NC}"; }
log_warn() { echo -e "${YELLOW}! $1${NC}"; }

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to add to PATH and persist
add_to_path() {
    local dir=$1
    if [[ ":$PATH:" != *":$dir:"* ]]; then
        export PATH="$dir:$PATH"
        echo "export PATH=\"$dir:\$PATH\"" >> ~/.bashrc
    fi
}

# Create a temporary directory for downloads
cd /tmp || exit 1

# Detect distribution and set package manager
if [ -f /etc/os-release ]; then
    . /etc/os-release
    case $ID in
        debian|ubuntu)
            PKG_MANAGER="apt-get"
            sudo $PKG_MANAGER update
            INSTALL_CMD="sudo $PKG_MANAGER install -y"
            ;;
        rhel|centos|rocky|almalinux|amzn)
            PKG_MANAGER="yum"
            sudo $PKG_MANAGER update -y
            INSTALL_CMD="sudo $PKG_MANAGER install -y"
            ;;
        *) log_error "Unsupported distribution: $ID"; exit 1 ;;
    esac
else
    log_error "Could not detect distribution"; exit 1
fi

# Install base dependencies
echo "Installing base dependencies..."
$INSTALL_CMD curl wget git unzip

# Install AWS CLI if not present
if ! command_exists aws; then
    log_warn "AWS CLI not found. Installing..."
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
    log_success "AWS CLI installed"
fi

# Install kubectl
if ! command_exists kubectl; then
    echo "Installing kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
    log_success "kubectl installed"
fi

# Install k9s
if ! command_exists k9s; then
    echo "Installing k9s..."
    curl -sS https://webinstall.dev/k9s | bash
    add_to_path "$HOME/.local/bin"
    log_success "k9s installed"
fi

# Install Helm
if ! command_exists helm; then
    echo "Installing Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    log_success "Helm installed"
fi

# Install ArgoCD CLI
if ! command_exists argocd; then
    echo "Installing ArgoCD CLI..."
    curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
    sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
    rm argocd-linux-amd64
    log_success "ArgoCD CLI installed"
fi

# Set up kubectl aliases
if ! grep -q "alias k=kubectl" ~/.bashrc; then
    echo "Setting up kubectl aliases..."
    {
        echo 'alias k=kubectl'
        echo 'alias p="kubectl get pods"'
        echo 'source <(kubectl completion bash)'
        echo 'complete -o default -F __start_kubectl k'
    } >> ~/.bashrc
    log_success "kubectl aliases added"
fi

# Configure kubectl context
echo "Configuring kubectl context..."
if command_exists aws; then
    aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION"
    log_success "kubectl context configured"
else
    log_error "AWS CLI not found. Please install it to configure kubectl context."
fi

# Clean up
cd "$HOME"

# Reload shell configuration
exec bash
log_success "Setup completed successfully!"
echo "All tools have been installed and configured."
