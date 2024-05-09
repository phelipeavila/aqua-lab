#!/bin/bash

validate_hardware_requirements() {
    local cpu_count=$(grep -c ^processor /proc/cpuinfo)
    local total_memory=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local total_memory_mb=$((total_memory / 1024))

    if [ "$cpu_count" -lt 2 ]; then
        echo "Error: Insufficient CPUs. The system requires at least 2 CPUs."
        exit 1
    fi

    if [ "$total_memory_mb" -lt 2028 ]; then
        echo "Error: Insufficient memory. The system requires at least 2GB of RAM."
        exit 1
    fi
}

# Function to install Docker
install_docker() {
    if ! command -v docker &> /dev/null; then
        echo "--> Installing Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh && sudo sh get-docker.sh || { echo "Failed to install Docker"; exit 1; }
        echo "--> Docker installed successfully."
        rm get-docker.sh
    else
        echo "--> Docker is already installed."
    fi
}

# Function to install Helm
install_helm() {
    if ! command -v helm &> /dev/null; then
        echo "--> Installing Helm..."
        curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash || { echo "Failed to install Helm"; exit 1; }
        echo "--> Helm installed successfully."
    else
        echo "--> Helm is already installed."
    fi
}

# Function to validate downloaded binary
validate_file() {
    if [ ! -f "$1" ]; then
        echo "Error: file not found."
        exit 1
    fi

    if [ ! -s "$1" ]; then
        echo "Error: file is empty."
        exit 1
    fi

    if [ "$(awk '{print tolower($0)}' "$1")" = "not found" ]; then
        echo "Error: file content is 'Not found'."
        exit 1
    fi
}

# Function to install kubectl
install_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        echo "--> Installing kubectl..."
        curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl || { echo "Failed to download kubectl"; exit 1; }
        validate_file ./kubectl
        chmod +x ./kubectl && sudo mv ./kubectl /usr/local/bin/kubectl || { echo "Failed to move kubectl to /usr/local/bin"; exit 1; }
        echo "--> kubectl installed successfully."
    else
        echo "--> kubectl is already installed."
    fi
}


# Function to install Kind
install_kind() {
    if ! command -v kind &> /dev/null; then
        echo "--> Installing Kind..."
        [ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.22.0/kind-linux-amd64 || { echo "Failed to download Kind"; exit 1; }
        validate_file ./kind
        chmod +x ./kind && sudo mv ./kind /usr/local/bin/kind || { echo "Failed to move Kind to /usr/local/bin"; exit 1; }
        echo "--> Kind installed successfully."
    else
        echo "--> Kind is already installed."
    fi
}

# Function to create Kubernetes cluster with Kind
create_kind_cluster() {
    local cluster_name="aqua-env"
    local config_file="cluster/extraPortMappings.yml"
    
    # Check if YAML file exists
    if [ ! -f "$config_file" ]; then
        echo "Error: YAML file '$config_file' not found."
        exit 1
    fi


    echo "--> Checking if cluster '$cluster_name' already exists..."
    if sudo kind get clusters | grep -q "$cluster_name"; then
        echo "--> Cluster '$cluster_name' already exists."
    else
        echo "--> Creating Kubernetes cluster with Kind..."
        sudo kind create cluster --name="$cluster_name" --config="$config_file" || { echo "Failed to create Kind cluster"; exit 1; }
        echo "--> Kind cluster created successfully."

        # Configure kubeconfig
        echo "--> Configuring kubeconfig..."
        mkdir -p ~/.kube
        sudo kind get kubeconfig --name=aqua-env > ~/.kube/config || { echo "Failed to configure kubeconfig"; exit 1; }
    fi

    # Apply Kubernetes manifests
    echo "--> Applying Kubernetes manifests..."
    kubectl apply -f cluster/verademo-dotnet-service.yml || { echo "Failed to apply VeraDemo .NET service manifest"; exit 1; }
    kubectl apply -f cluster/verademo-dotnet-deployment.yml || { echo "Failed to apply VeraDemo .NET deployment manifest"; exit 1; }
    kubectl apply -f cluster/verademo-java-service.yml || { echo "Failed to apply VeraDemo Java service manifest"; exit 1; }
    kubectl apply -f cluster/verademo-java-deployment.yml || { echo "Failed to apply VeraDemo Java deployment manifest"; exit 1; }
    kubectl apply -f cluster/pygoat-service.yml || { echo "Failed to apply PyGoat service manifest"; exit 1; }
    kubectl apply -f cluster/pygoat-deployment.yml || { echo "Failed to apply PyGoat deployment manifest"; exit 1; }
}

# Main script
validate_hardware_requirements
install_docker
install_helm
install_kubectl
install_kind

echo "--> Installation completed successfully."

create_kind_cluster
echo "--> Configuration completed successfully."

