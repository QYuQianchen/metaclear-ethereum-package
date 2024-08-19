#!/usr/bin/env bash

# Get the directory of the current script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

source "$SCRIPT_DIR/utils.sh"

# Function to check if the image is loaded in Minikube
check_image_in_minikube() {
    local image=$1
    if minikube image ls | grep -q "$image"; then
        echo "$image is already loaded in Minikube."
    else
        echo "$image is NOT found in Minikube. Please build them and load them into Minikube. \n
        Consider use the following command: \n
        docker build -f Dockerfile -t "$image" . && minikube image load "$image"
        "
        return 1
    fi
}


# Main script execution
# Check if minikube is installed
check_installation "minikube"

# check if minikube is running
if minikube status -f "{{.Host}}" | grep -q "Running"; then
  echo "Minikube is already running."
else
  echo "Minikube is not running. Starting Minikube..."

  # Start minikube
  minikube start --driver=docker --alsologtostderr --extra-config=kube-proxy.mode=iptables && eval $(minikube -p minikube docker-env)
  if [ $? -eq 0 ]; then
    echo "Minikube started successfully."
  else
    echo "Failed to start Minikube."
    exit 1
  fi
fi
echo "Please follow https://docs.kurtosis.com/k8s to configure kurtosis for minikube."

# Extract image names from network.yaml
mev_relay_image=$(extract_image_name "mev_relay_image" "$SCRIPT_DIR/network_params.yaml")
mev_builder_cl_image=$(extract_image_name "mev_builder_cl_image" "$SCRIPT_DIR/network_params.yaml")

# Check if the images are loaded in Minikube
all_images_loaded=true

check_image_in_minikube "$mev_relay_image" || all_images_loaded=false
check_image_in_minikube "$mev_builder_cl_image" || all_images_loaded=false

# Print a message if any images are missing
if [ "$all_images_loaded" = false ]; then
    echo "Please build and load the missing images into Minikube."
fi

# setup metrics for minikube
minikube addons enable metrics-server
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
helm upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard --create-namespace --namespace kubernetes-dashboard
kubectl apply -f "$SCRIPT_DIR/static_files/kubernetes-config/dashboard-admin-user-creation.yaml"
kubectl apply -f "$SCRIPT_DIR/static_files/kubernetes-config/dashboard-admin-user-binding.yaml"
kubectl apply -f "$SCRIPT_DIR/static_files/kubernetes-config/dashboard-admin-user-secret.yaml"

# launch kurtosis
echo "Please open a new terminal tab and run:
  kurtosis engine start && kurtosis gateway
"

# launch the network
echo "Please open a new terminal tab and run:
  source "$SCRIPT_DIR/utils.sh"
  kurtosis --enclave relaytestnet run "$SCRIPT_DIR" --args-file "$SCRIPT_DIR/network_params.yaml"
"

# port forward the dashboard
if kubectl -n kubernetes-dashboard get svc &> /dev/null | grep -q "kubernetes-dashboard-kong-proxy"; then
  echo "Kubernetes dashboard is already port forwarded."
else
  kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard-kong-proxy 8443:443
fi
