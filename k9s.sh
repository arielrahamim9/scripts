# To run this script directly from GitHub raw:
# curl -sSL https://raw.githubusercontent.com/arielrahamim9/scripts/refs/heads/main/k9s.sh | sh
#!/bin/bash

# Configuration
CLUSTER_NAME="hyperspace-tfc-simulation"
REGION="eu-west-2"

# Install required dependencies
echo "Installing required dependencies..."
sudo apt-get install -y curl wget

# Set up kubectl aliases
echo "Setting up kubectl aliases..."
echo 'alias k=kubectl' >> ~/.bashrc
echo 'alias p="kubectl get pods"' >> ~/.bashrc

# Install k9s
echo "Installing k9s..."
curl -sS https://webi.sh/k9s | sh
# shellcheck source=/dev/null
source ~/.config/envman/PATH.env

# Install Helm
echo "Installing Helm..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install ArgoCD CLI
echo "Installing ArgoCD CLI..."
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64

# Configure kubectl context
echo "Configuring kubectl context..."
aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION

# Source the updated bashrc
source ~/.bashrc

echo "Setup completed successfully!"
echo "Please ensure you have AWS CLI configured with appropriate credentials."
echo "You can now use the following commands:"
echo "- 'k' for kubectl"
echo "- 'p' for kubectl get pods"
echo "- 'k9s' for the k9s interface"
echo "- 'helm' for helm commands"
echo "- 'argocd' for ArgoCD CLI" 
