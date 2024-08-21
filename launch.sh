#!/usr/bin/env bash

# Get the directory of the current script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

source "$SCRIPT_DIR/utils.sh"

# Function to check if the image is loaded in Minikube
check_image_in_minikube() {
  local image_key=$1
  local config_yaml=$2

  # extract image name from the YAML file
  printf "Check if %s is present in %s...\n" "$image_key" "$config_yaml"
  local image=$(grep -E '(^|\s)"$image_key"' "$config_yaml" | awk '{print $2}')

  if minikube image ls | grep -q "$image"; then
    echo "$image is already loaded in Minikube."
  else
    echo "$image is NOT found in Minikube. Please build them and load them into Minikube.
    Consider use the following command:
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
  echo "Minikube has already been running."
else
  echo "Minikube is not running. Starting Minikube..."

  # Start minikube
  minikube start --driver=docker --alsologtostderr --extra-config=kube-proxy.mode=iptables && eval $(minikube -p minikube docker-env)
  if [ $? -eq 0 ]; then
    echo "Minikube started successfully."
  else
    echo "🚨 Failed to start Minikube."
    exit 1
  fi
fi
echo "💡 Please follow https://docs.kurtosis.com/k8s to configure kurtosis for minikube.
"

# Check if the images are loaded in Minikube
all_images_loaded=true
check_image_in_minikube "mev_relay_image" "$SCRIPT_DIR/network_params.yaml" || all_images_loaded=false
check_image_in_minikube "mev_builder_cl_image" "$SCRIPT_DIR/network_params.yaml" || all_images_loaded=false

# Print a message if any images are missing
if [ "$all_images_loaded" = false ]; then
    echo "🚨 Please build and load the missing images into Minikube.
"
fi

# setup metrics for minikube
minikube addons enable metrics-server
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
helm upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard --create-namespace --namespace kubernetes-dashboard
kubectl apply -f "$SCRIPT_DIR/static_files/kubernetes-config/dashboard-admin-user-creation.yaml"
kubectl apply -f "$SCRIPT_DIR/static_files/kubernetes-config/dashboard-admin-user-binding.yaml"
kubectl apply -f "$SCRIPT_DIR/static_files/kubernetes-config/dashboard-admin-user-secret.yaml"

# launch kurtosis
echo "
💡 Please open a new terminal tab and run:
  kurtosis engine start && kurtosis gateway
"

# launch the network
echo "💡 Please open a new terminal tab and run:
  source "$SCRIPT_DIR/utils.sh" && kurtosis --enclave relaytestnet run "$SCRIPT_DIR" --args-file "$SCRIPT_DIR/network_params.yaml"
"

# Run some network tests
echo "💡 Once the kurtosis network is running, you can run some network tests:
  1. Launch a ping test: \`launch_ping_test\`
  2. Launch a syn flood attack: \`launch_syn_flood_test\`
  3. Launch attacknet: \`launch_attacknet\`
"

# port forward the dashboard
if kubectl -n kubernetes-dashboard get svc &> /dev/null | grep -q "kubernetes-dashboard-kong-proxy"; then
  echo "Kubernetes dashboard is already port forwarded."
else
  kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard-kong-proxy 8443:443
fi
