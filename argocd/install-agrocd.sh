#!/bin/bash

# ArgoCD Installation Script for Ubuntu on GCP VM
# This script installs ArgoCD on port 8090 (since 8080 is busy)
# and configures it for external access
# Usage: ./install-argocd.sh [install|uninstall|reinstall]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ARGOCD_VERSION="v2.9.3"  # Latest stable version as of script creation
ARGOCD_PORT=8090         # Using 8090 since 8080 is busy
ARGOCD_NAMESPACE="argocd"
KIND_CLUSTER_NAME="kind"

# Get command line argument
ACTION=${1:-install}

# Function to print status
print_status() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================${NC}"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [install|uninstall|reinstall]"
    echo ""
    echo "Commands:"
    echo "  install    - Install ArgoCD (default)"
    echo "  uninstall  - Uninstall ArgoCD and cleanup"
    echo "  reinstall  - Uninstall and then install ArgoCD"
    echo ""
}

# Function to check if ArgoCD is installed
check_argocd_installation() {
    local installed=false
    
    # Check if ArgoCD namespace exists
    if kubectl get namespace ${ARGOCD_NAMESPACE} &>/dev/null; then
        print_status "ArgoCD namespace exists"
        installed=true
    fi
    
    # Check if kind cluster exists
    if command -v kind &>/dev/null && kind get clusters 2>/dev/null | grep -q "^${KIND_CLUSTER_NAME}$"; then
        print_status "Kind cluster '${KIND_CLUSTER_NAME}' exists"
        installed=true
    fi
    
    return $([ "$installed" = true ] && echo 0 || echo 1)
}

# Function to uninstall ArgoCD
uninstall_argocd() {
    print_header "🗑️  Uninstalling ArgoCD"
    
    # Stop any port forwarding processes
    print_status "Stopping any port-forward processes..."
    pkill -f "kubectl.*port-forward.*argocd" 2>/dev/null || true
    
    # Delete ArgoCD namespace and resources
    if kubectl get namespace ${ARGOCD_NAMESPACE} &>/dev/null; then
        print_status "Deleting ArgoCD namespace and all resources..."
        kubectl delete namespace ${ARGOCD_NAMESPACE} --timeout=300s
        print_success "ArgoCD namespace deleted"
    else
        print_status "ArgoCD namespace not found"
    fi
    
    # Delete kind cluster
    if command -v kind &>/dev/null && kind get clusters 2>/dev/null | grep -q "^${KIND_CLUSTER_NAME}$"; then
        print_status "Deleting kind cluster..."
        kind delete cluster --name ${KIND_CLUSTER_NAME}
        print_success "Kind cluster deleted"
    else
        print_status "Kind cluster not found"
    fi
    
    # Remove GCP firewall rule if exists
    if command -v gcloud &>/dev/null; then
        print_status "Removing GCP firewall rule..."
        gcloud compute firewall-rules delete allow-argocd-${ARGOCD_PORT} --quiet 2>/dev/null || print_status "Firewall rule not found or already deleted"
    fi
    
    # Clean up credential files
    if [ -f "argocd-credentials.txt" ]; then
        rm -f argocd-credentials.txt
        print_status "Removed credential file"
    fi
    
    # Remove Docker containers if any are running
    print_status "Cleaning up any remaining Docker containers..."
    docker ps -a --filter "label=io.x-k8s.kind.cluster=${KIND_CLUSTER_NAME}" --format "{{.ID}}" | xargs -r docker rm -f 2>/dev/null || true
    
    print_success "ArgoCD uninstallation completed!"
}

# Main installation function
install_argocd() {
    print_header "🚀 Starting ArgoCD installation on Ubuntu"

    # Check if running as root or with sudo
    if [[ $EUID -eq 0 ]]; then
       print_error "This script should not be run as root. Please run as a regular user with sudo privileges."
       exit 1
    fi

    # Update system packages
    print_status "Updating system packages..."
    sudo apt update && sudo apt upgrade -y

    # Install required dependencies
    print_status "Installing required dependencies..."
    sudo apt install -y curl wget apt-transport-https ca-certificates gnupg lsb-release

    # Install Docker if not already installed
    if ! command -v docker &> /dev/null; then
        print_status "Installing Docker..."
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt update
        sudo apt install -y docker-ce docker-ce-cli containerd.io
        sudo usermod -aG docker $USER
        print_success "Docker installed successfully"
    else
        print_success "Docker is already installed"
    fi

    # Install kubectl if not already installed
    if ! command -v kubectl &> /dev/null; then
        print_status "Installing kubectl..."
        curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/kubernetes-archive-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
        sudo apt update
        sudo apt install -y kubectl
        print_success "kubectl installed successfully"
    else
        print_success "kubectl is already installed"
    fi

    # Install kind (Kubernetes in Docker) for local cluster
    if ! command -v kind &> /dev/null; then
        print_status "Installing kind (Kubernetes in Docker)..."
        curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
        chmod +x ./kind
        sudo mv ./kind /usr/local/bin/kind
        print_success "kind installed successfully"
    else
        print_success "kind is already installed"
    fi

    # Create kind cluster if it doesn't exist
    print_status "Checking for existing kind cluster..."
    if ! kind get clusters | grep -q "kind"; then
        print_status "Creating kind cluster with port mapping..."
        cat <<EOF > kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 30080
    hostPort: ${ARGOCD_PORT}
    protocol: TCP
EOF
        
        kind create cluster --config=kind-config.yaml
        rm kind-config.yaml
        print_success "kind cluster created successfully"
    else
        print_success "kind cluster already exists"
    fi

    # Wait for cluster to be ready
    print_status "Waiting for cluster to be ready..."
    kubectl cluster-info --context kind-kind
    kubectl wait --for=condition=Ready nodes --all --timeout=300s

    # Create ArgoCD namespace
    print_status "Creating ArgoCD namespace..."
    kubectl create namespace ${ARGOCD_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

    # Install ArgoCD
    print_status "Installing ArgoCD ${ARGOCD_VERSION}..."
    kubectl apply -n ${ARGOCD_NAMESPACE} -f https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml

    # Wait for ArgoCD pods to be ready
    print_status "Waiting for ArgoCD pods to be ready (this may take a few minutes)..."
    kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n ${ARGOCD_NAMESPACE}
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n ${ARGOCD_NAMESPACE} --timeout=600s

    # Patch ArgoCD server service to use NodePort
    print_status "Configuring ArgoCD server for external access..."
    kubectl patch svc argocd-server -n ${ARGOCD_NAMESPACE} -p '{"spec":{"type":"NodePort","ports":[{"port":80,"targetPort":8080,"nodePort":30080}]}}'

    # Configure ArgoCD server to accept insecure connections (for HTTP access)
    kubectl patch configmap argocd-cmd-params-cm -n ${ARGOCD_NAMESPACE} --patch '{"data":{"server.insecure":"true"}}'

    # Restart ArgoCD server to apply changes
    kubectl rollout restart deployment argocd-server -n ${ARGOCD_NAMESPACE}
    kubectl rollout status deployment argocd-server -n ${ARGOCD_NAMESPACE}

    # Get initial admin password
    print_status "Retrieving ArgoCD admin password..."
    ARGOCD_PASSWORD=$(kubectl -n ${ARGOCD_NAMESPACE} get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

    # Get VM's public IP
    print_status "Retrieving VM public IP..."
    PUBLIC_IP=$(curl -s ifconfig.me)

    # Configure firewall rule for GCP (if gcloud is available)
    if command -v gcloud &> /dev/null; then
        print_status "Configuring GCP firewall rule for ArgoCD..."
        gcloud compute firewall-rules create allow-argocd-${ARGOCD_PORT} \
            --allow tcp:${ARGOCD_PORT} \
            --source-ranges 0.0.0.0/0 \
            --description "Allow ArgoCD access on port ${ARGOCD_PORT}" \
            2>/dev/null || print_status "Firewall rule may already exist or gcloud not configured"
    else
        print_status "gcloud CLI not found. Please manually configure GCP firewall:"
        echo "  - Rule name: allow-argocd-${ARGOCD_PORT}"
        echo "  - Direction: Ingress"
        echo "  - Action: Allow"
        echo "  - Targets: All instances in network"
        echo "  - Source IP ranges: 0.0.0.0/0"
        echo "  - Protocols and ports: TCP ${ARGOCD_PORT}"
    fi

    # Create ArgoCD CLI alias for convenience
    print_status "Setting up ArgoCD CLI..."
    if ! command -v argocd &> /dev/null; then
        curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-linux-amd64
        sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
        rm argocd-linux-amd64
        print_success "ArgoCD CLI installed successfully"
    fi

    print_success "ArgoCD installation completed successfully!"

    echo ""
    echo "=================================="
    echo "🚀 ArgoCD Access Information"
    echo "=================================="
    echo ""
    echo "📍 ArgoCD URL: http://${PUBLIC_IP}:${ARGOCD_PORT}"
    echo "👤 Username: admin"
    echo "🔑 Password: ${ARGOCD_PASSWORD}"
    echo ""
    echo "💡 Additional Commands:"
    echo "  - Access ArgoCD locally: kubectl port-forward svc/argocd-server -n argocd 8090:80"
    echo "  - Change admin password: argocd account update-password"
    echo "  - Get pods status: kubectl get pods -n argocd"
    echo ""
    echo "🔧 Troubleshooting:"
    echo "  - Check ArgoCD status: kubectl get all -n argocd"
    echo "  - View ArgoCD logs: kubectl logs -n argocd deployment/argocd-server"
    echo "  - Restart ArgoCD: kubectl rollout restart deployment argocd-server -n argocd"
    echo ""
    echo "⚠️  Security Notes:"
    echo "  - ArgoCD is configured for HTTP (insecure) access for simplicity"
    echo "  - For production, configure HTTPS with proper certificates"
    echo "  - Change the default admin password immediately"
    echo "  - Consider restricting firewall access to specific IP ranges"
    echo ""

    # Save credentials to file for future reference
    cat > argocd-credentials.txt << EOF
ArgoCD Access Information
========================
URL: http://${PUBLIC_IP}:${ARGOCD_PORT}
Username: admin
Password: ${ARGOCD_PASSWORD}
Created: $(date)
EOF

    print_success "Credentials saved to argocd-credentials.txt"
    echo "🎉 You can now access ArgoCD at: http://${PUBLIC_IP}:${ARGOCD_PORT}"
}

# Main script logic
case $ACTION in
    "install")
        # Check if already installed
        if check_argocd_installation; then
            print_error "ArgoCD appears to be already installed!"
            echo ""
            echo "Options:"
            echo "  1. Run '$0 uninstall' to remove existing installation"
            echo "  2. Run '$0 reinstall' to uninstall and reinstall"
            echo "  3. Access existing installation (credentials may be in argocd-credentials.txt)"
            exit 1
        fi
        install_argocd
        ;;
    "uninstall")
        if ! check_argocd_installation; then
            print_error "ArgoCD doesn't appear to be installed"
            exit 1
        fi
        uninstall_argocd
        ;;
    "reinstall")
        print_header "♻️  Reinstalling ArgoCD"
        if check_argocd_installation; then
            uninstall_argocd
            echo ""
            print_status "Waiting 10 seconds before reinstalling..."
            sleep 10
        fi
        install_argocd
        ;;
    "-h"|"--help"|"help")
        show_usage
        exit 0
        ;;
    *)
        print_error "Invalid action: $ACTION"
        show_usage
        exit 1
        ;;
esac
