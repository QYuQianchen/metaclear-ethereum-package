#!/usr/bin/env bash

# Helper function to check if a CLI is installed
check_installation() {
  local cmd="$1"
  if ! command -v "$cmd" &> /dev/null; then
      echo "$cmd is not installed. Please install $cmd..."
      exit 1
  else
    echo "$cmd is already installed."
  fi
}

# Function to extract image name from the YAML file
extract_image_name() {
  local image_key=$1
  local config_yaml=$2
  echo "Check if $image_key is present in $config_yaml..."
  grep "$image_key" "$config_yaml" | awk '{print $2}'
}

# clean up kurtosis enclave
kurtosis_cleanup() {
  kurtosis enclave stop relaytestnet
  kurtosis enclave rm relaytestnet
  kurtosis clean -a
}

kubectl_cleanup() {
  kubectl delete ns "kt-relaytestnet" --grace-period=0 --force
}

# Open the UI of a service
open_ui() {
  local service_name=$1
  local url=$(kurtosis enclave inspect relaytestnet | grep -E "(^|\s)$service_name($|\s)" | awk -F ' -> ' '{split($2, a, " "); print a[1]}')
  if [ -n "$url" ]; then
      echo "Opening $service_name at $url"
      open "$url"
  else
      echo "URL for $service_name not found."
  fi
}

# Launch attacknet
launch_attacknet() {
  # create kubectl namespace
  echo "Creating kubectl namespace ..."
  kubectl create ns chaos-mesh
  echo "Namespace chaos-mesh is created."

  # install chaos-mesh
  echo "Installing attacknet via helm..."
  helm repo add chaos-mesh https://charts.chaos-mesh.org
  helm install chaos-mesh chaos-mesh/chaos-mesh -n=chaos-mesh --version 2.6.3 --set dashboard.securityMode=false --set bpfki.create=true
  echo "Attacknet is installed."

  # port forward the dashboard
  echo "Use the following command to access the dashboard:
    kubectl --namespace chaos-mesh port-forward svc/chaos-dashboard 2333
  "
}

mem_attack_client() {
  local attacknet_path=$1
  local current_dir=$(pwd)
  # go to attacknet directory
  echo "Go to attacknet directory..."
  cd "$attacknet_path"

  echo "Launch memory stress-test..."
  attacknet start metaclear-dos-memory-stress

  echo "Back to current directory..."
  cd "$current_dir"
}
