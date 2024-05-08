#!/bin/bash

# Function to check if file exists, is not empty, and does not contain "Not found"
validate_file() {
    local file=$1
    if [ ! -f "$file" ]; then
        echo "Error: File '$file' not found."
        exit 1
    fi
    if [ ! -s "$file" ]; then
        echo "Error: File '$file' is empty."
        exit 1
    fi
    if [ "$( awk '{print toupper($0)}' aa)" = "NOT FOUND" ]; then
        echo "Error: File '$file' content is 'Not found'."
        exit 1
    fi
}

# Install Docker
echo "Installing Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh && sudo sh get-docker.sh || { echo "Failed to install Docker"; exit 1; }

# Install Helm
echo "Installing Helm..."
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash || { echo "Failed to install Helm"; exit 1; }

# Install kubectl
echo "Installing kubectl..."
curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl || { echo "Failed to download kubectl"; exit 1; }
chmod +x ./kubectl && sudo mv ./kubectl /usr/local/bin/kubectl || { echo "Failed to move kubectl to /usr/local/bin"; exit 1; }

# Install Kind
echo "Installing Kind..."
[ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.22.0/kind-linux-amd64 || { echo "Failed to download Kind"; exit 1; }
validate_file ./kind
chmod +x ./kind && sudo mv ./kind /usr/local/bin/kind || { echo "Failed to move Kind to /usr/local/bin"; exit 1; }

# Check if the downloaded files are okay
# [Add code here]

# Check if YAML file exists
if [ ! -f "cluster/extraPortMappings.yml" ]; then
    echo "Error: YAML file 'cluster/extraPortMappings.yml' not found."
    exit 1
fi

# Create Kubernetes cluster with Kind
echo "Creating Kubernetes cluster with Kind..."
sudo kind create cluster --name=aqua-env --config=cluster/extraPortMappings.yml || { echo "Failed to create Kind cluster"; exit 1; }

# Configure kubeconfig
echo "Configuring kubeconfig..."
mkdir -p ~/.kube
sudo kind get kubeconfig --name=aqua-env > ~/.kube/config || { echo "Failed to configure kubeconfig"; exit 1; }

# Apply Kubernetes manifests
echo "Applying Kubernetes manifests..."
kubectl apply -f cluster/verademo-dotnet-service.yml || { echo "Failed to apply VeraDemo .NET service manifest"; exit 1; }
kubectl apply -f cluster/verademo-dotnet-deployment.yml || { echo "Failed to apply VeraDemo .NET deployment manifest"; exit 1; }
kubectl apply -f cluster/verademo-java-service.yml || { echo "Failed to apply VeraDemo Java service manifest"; exit 1; }
kubectl apply -f cluster/verademo-java-deployment.yml || { echo "Failed to apply VeraDemo Java deployment manifest"; exit 1; }
kubectl apply -f cluster/pygoat-service.yml || { echo "Failed to apply PyGoat service manifest"; exit 1; }
kubectl apply -f cluster/pygoat-dotnet-deployment.yml || { echo "Failed to apply PyGoat .NET deployment manifest"; exit 1; }

echo "Cluster setup completed successfully."
