#!/bin/bash
set -e

# To run this script directly from GitHub raw:
# curl -sSL https://raw.githubusercontent.com/arielrahamim9/scripts/refs/heads/main/script.sh | bash
#
# Command to assume role and set AWS Credentials
# eval $(aws sts assume-role --role-arn "arn:aws:iam::337450623971:role/PlatformAdmin" \
#   --role-session-name "test" \
#   --output text \
#   --query 'Credentials.[join(`=`, [`AWS_ACCESS_KEY_ID`, AccessKeyId]), join(`=`, [`AWS_SECRET_ACCESS_KEY`, SecretAccessKey]), join(`=`, [`AWS_SESSION_TOKEN`, SessionToken])]' | \
#   sed 's/^/export /')
#
# kubectl context configuration
# aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION"




# Configuration
CLUSTER_NAME="hyperspace-tfc-simulation"
REGION="eu-west-2"
DCV=${DCV:-"no"}  # Default to no, can be overridden with DCV=yes

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

# Function to install DCV and prerequisites
dcv() {
    if [ "$DCV" != "yes" ]; then
        log_warn "DCV installation skipped (set DCV=yes to install)"
        return
    fi

    log_warn "Installing DCV and prerequisites..."
    
    # Create temporary directory for DCV installation
    cd /tmp || exit 1

    # Detect distribution and install accordingly
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case $ID in
            ubuntu)
                # Install prerequisites
                sudo apt update
                sudo apt install -y ubuntu-desktop gdm3
                sudo sed -i 's/#WaylandEnable=false/WaylandEnable=false/' /etc/gdm3/custom.conf
                sudo systemctl restart gdm3

                # Import GPG key
                wget https://d1uj6qtbmh3dt5.cloudfront.net/NICE-GPG-KEY
                gpg --import NICE-GPG-KEY

                # Download and install DCV
                case $VERSION_ID in
                    20.04)
                        wget https://d1uj6qtbmh3dt5.cloudfront.net/nice-dcv-ubuntu2004-x86_64.tgz
                        tar -xvzf nice-dcv-ubuntu2004-x86_64.tgz
                        cd nice-dcv-ubuntu2004-x86_64 || exit 1
                        sudo apt install ./nice-dcv-server_*.deb
                        sudo apt install ./nice-dcv-web-viewer_*.deb
                        sudo apt install ./nice-xdcv_*.deb
                        ;;
                    22.04)
                        wget https://d1uj6qtbmh3dt5.cloudfront.net/nice-dcv-ubuntu2204-x86_64.tgz
                        tar -xvzf nice-dcv-ubuntu2204-x86_64.tgz
                        cd nice-dcv-ubuntu2204-x86_64 || exit 1
                        sudo apt install ./nice-dcv-server_*.deb
                        sudo apt install ./nice-dcv-web-viewer_*.deb
                        sudo apt install ./nice-xdcv_*.deb
                        ;;
                    *)
                        log_error "Unsupported Ubuntu version: $VERSION_ID"
                        return 1
                        ;;
                esac
                ;;
            amzn)
                if [ "$VERSION_ID" = "2023" ]; then
                    # Amazon Linux 2023 prerequisites
                    sudo dnf groupinstall -y 'Desktop'
                    sudo sed -i 's/#WaylandEnable=false/WaylandEnable=false/' /etc/gdm/custom.conf
                    sudo systemctl restart gdm

                    # Import GPG key
                    sudo rpm --import https://d1uj6qtbmh3dt5.cloudfront.net/NICE-GPG-KEY

                    # Download and install DCV
                    wget https://d1uj6qtbmh3dt5.cloudfront.net/nice-dcv-amzn2023-x86_64.tgz
                    tar -xvzf nice-dcv-amzn2023-x86_64.tgz
                    cd nice-dcv-amzn2023-x86_64 || exit 1
                    sudo dnf install nice-dcv-server-*.rpm
                    sudo dnf install nice-dcv-web-viewer-*.rpm
                    sudo dnf install nice-xdcv-*.rpm
                else
                    # Amazon Linux 2 prerequisites
                    sudo yum install -y gdm gnome-session gnome-classic-session gnome-session-xsession
                    sudo yum install -y xorg-x11-server-Xorg xorg-x11-fonts-Type1 xorg-x11-drivers
                    sudo sed -i 's/#WaylandEnable=false/WaylandEnable=false/' /etc/gdm/custom.conf
                    sudo systemctl restart gdm

                    # Import GPG key
                    sudo rpm --import https://d1uj6qtbmh3dt5.cloudfront.net/NICE-GPG-KEY

                    # Download and install DCV
                    wget https://d1uj6qtbmh3dt5.cloudfront.net/nice-dcv-amzn2-x86_64.tgz
                    tar -xvzf nice-dcv-amzn2-x86_64.tgz
                    cd nice-dcv-amzn2-x86_64 || exit 1
                    sudo yum install nice-dcv-server-*.rpm
                    sudo yum install nice-dcv-web-viewer-*.rpm
                    sudo yum install nice-xdcv-*.rpm
                fi
                ;;
            *)
                log_error "Unsupported distribution for DCV installation: $ID"
                return 1
                ;;
        esac

        # Configure X server to start automatically
        if [ "$(systemctl get-default)" != "graphical.target" ]; then
            sudo systemctl set-default graphical.target
        fi

        # Add dcv user to video group
        sudo usermod -aG video dcv

        # Clean up
        cd "$HOME"
        rm -rf /tmp/nice-dcv-*

        # Start DCV services
        sudo systemctl start dcv-server || log_error "Failed to start DCV server"
        sudo systemctl enable dcv-server || log_error "Failed to enable DCV server"
        
        log_success "DCV installed successfully"
    else
        log_error "Could not detect distribution for DCV installation"
        return 1
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
            PKG_MANAGER="dnf"
            # For CentOS Stream, we need to handle package conflicts
            if [ "$ID" = "centos" ] && [ "$VERSION_ID" = "9" ]; then
                sudo $PKG_MANAGER clean all
                sudo $PKG_MANAGER makecache
                INSTALL_CMD="sudo $PKG_MANAGER install -y --allowerasing"
            else
                sudo $PKG_MANAGER update -y
                INSTALL_CMD="sudo $PKG_MANAGER install -y"
            fi
            ;;
        *) log_error "Unsupported distribution: $ID"; exit 1 ;;
    esac
else
    log_error "Could not detect distribution"; exit 1
fi

# Install base dependencies
echo "Installing base dependencies..."
$INSTALL_CMD curl wget git unzip jq

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
    success=0
    for attempt in {1..3}; do
        if aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$REGION"; then
            log_success "kubectl context configured"
            success=1
            break
        else
            log_warn "Attempt $attempt to configure kubectl context failed."
        fi
    done
    if [ $success -eq 0 ]; then
        log_warn "Trying to assume role and update kubeconfig..."
        eval "$(aws sts assume-role --role-arn "arn:aws:iam::337450623971:role/PlatformAdmin" --role-session-name "test" --output text --query "Credentials.[join('=', ['AWS_ACCESS_KEY_ID', AccessKeyId]), join('=', ['AWS_SECRET_ACCESS_KEY', SecretAccessKey]), join('=', ['AWS_SESSION_TOKEN', SessionToken])]" | sed 's/^/export /')"
        log_success "kubectl context configured after assuming role"
    else
        log_error "Failed to configure kubectl context even after assuming role."
    fi
else
    log_error "AWS CLI not found. Please install it to configure kubectl context."
fi

# Install DCV
if ! command_exists dcv; then
    dcv
else
    log_success "DCV is already installed. Skipping installation."
fi

# Clean up
cd "$HOME"

# Reload shell configuration
bash
log_success "Setup completed successfully!"
echo "All tools have been installed and configured."
