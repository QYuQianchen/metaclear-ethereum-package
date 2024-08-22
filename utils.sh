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

# clean up kurtosis enclave
kurtosis_cleanup() {
  local enclave_name="${1:-relaytestnet}"
  kurtosis enclave stop $enclave_name
  kurtosis enclave rm $enclave_name
  kurtosis clean -a
}

kubectl_cleanup() {
  local ns_name="${1:-kt-relaytestnet}"
  kubectl delete ns $ns_name --grace-period=0 --force
}

# When the namespace gets stuck in terminating state
# see status from `kubectl get ns`
kubectl_terminate() {
  local ns_name="${1:-kt-relaytestnet}"
  kubectl get ns $ns_name -ojson | jq '.spec.finalizers = []' | kubectl replace --raw "/api/v1/namespaces/$ns_name/finalize" -f -
  kubectl get ns $ns_name -ojson | jq '.metadata.finalizers = []' | kubectl replace --raw "/api/v1/namespaces/$ns_name/finalize" -f -
}

# Open the UI of a service
open_ui() {
  local service_name=$1
  local enclave_name="${2:-relaytestnet}"
  local url=$(kurtosis enclave inspect "$enclave_name" | grep -E "(^|\s)$service_name($|\s)" | awk -F ' -> ' '{split($2, a, " "); print a[1]}')
  if [ -n "$url" ]; then
      echo "Opening $service_name at $url"
      open "$url"
  else
      echo "URL for $service_name not found."
  fi
}

# Simple test on ping and syn packet sending
get_pod_endpoint_service_ip() {
  local service_name="${1:-cl-1-lighthouse-geth}"  # Use input or default to "cl-1-lighthouse-geth"
  local enclave_name="${2:-relaytestnet}"

  echo "Getting pod endpoint with:
      kubectl get pods -n kt-$enclave_name -o wide | grep "$service_name" | awk '{print $6}'"
  export POD_ENDPOINT=$(kubectl get pods -n kt-$enclave_name -o wide | grep "$service_name" | awk '{print $6}')

  echo "Getting service IP with:
      kubectl get svc -n kt-$enclave_name -o wide | grep "$service_name" | awk '{print $3}'"
  export SERVICE_IP=$(kubectl get svc -n kt-"$enclave_name" -o wide | grep "$service_name" | awk '{print $3}')

  echo "\nFor $service_name in $enclave_name:
  The pod endpoint is: $POD_ENDPOINT
  The service IP is: $SERVICE_IP
  "
}

get_kubectl_dashboard_token() {
  echo "Getting kubectl dashboard token..."
  kubectl get secret admin-user -n kubernetes-dashboard -o jsonpath={".data.token"} | base64 -d
}

# e.g. connect_to_pod syn-flood
# e.g. connect_to_pod cl-1-lighthouse-geth
connect_to_pod() {
  local service_name="${1:-cl-1-lighthouse-geth}"  #
  local enclave_name="${2:-relaytestnet}"
  echo "kubectl exec -it -n kt-$enclave_name $service_name -- /bin/sh"
  kubectl exec -it -n kt-"$enclave_name" $service_name -- /bin/sh
}

# Launch Ping test
launch_ping_test() {
  local service_name="${1:-cl-1-lighthouse-geth}"  # Use input or default to "cl-1-lighthouse-geth"
  local enclave_name="${2:-relaytestnet}"
  echo "Get service IP and pod endpoint..."
  get_pod_endpoint_service_ip "$service_name" "$enclave_name"

  echo "Please use two separate terminals to run the following commands:"
  echo "\nTerminal 1 for CL service:
  source /Users/qyu/Documents/ethereum-package/utils.sh && connect_to_pod $service_name $enclave_name
  tcpdump -n icmp"
  echo "\nTerminal 2 for attacker:
  source /Users/qyu/Documents/ethereum-package/utils.sh && connect_to_pod "syn-flood" $enclave_name
  ping $POD_ENDPOINT"

  local dashboard_url="https://localhost:8443/#/pod/kt-$enclave_name/$service_name?namespace=_all"
  echo "\nUse kubectl admin pannel to check the container resources:
  $dashboard_url

  where token can be obtained from \`get_kubectl_dashboard_token\`
  "
  open "$dashboard_url"
}

launch_syn_flood_test() {
  local service_name="${1:-cl-1-lighthouse-geth}"  # Use input or default to "cl-1-lighthouse-geth"
  local enclave_name="${2:-relaytestnet}"
  echo "Get service IP and pod endpoint..."
  get_pod_endpoint_service_ip "$service_name" "$enclave_name"

  echo "Please use two separate terminals to run the following commands:"
  echo "\nTerminal 1 for CL service:
  source /Users/qyu/Documents/ethereum-package/utils.sh && connect_to_pod $service_name $enclave_name
  tcpdump -n tcp and port 9000 and 'tcp[tcpflags] & tcp-syn == tcp-syn'"
  echo "\nTerminal 2 for attacker:
  source /Users/qyu/Documents/ethereum-package/utils.sh && connect_to_pod "syn-flood" $enclave_name
  hping3 -S -D -c 15000 -p 9000 -d 200 --flood --rand-source $SERVICE_IP"

  local dashboard_url="https://localhost:8443/#/pod/kt-$enclave_name/$service_name?namespace=_all"
  echo "\nUse kubectl admin pannel to check the container resources:
  $dashboard_url

  where token can be obtained from \`get_kubectl_dashboard_token\`
  "
  open "$dashboard_url"
}

# Launch attacknet
launch_attacknet() {
  # create kubectl namespace
  echo "Creating kubectl namespace ..."
  kubectl create ns chaos-mesh
  echo "Namespace chaos-mesh is created."

  check_installation "helm"

  # install chaos-mesh
  echo "Installing attacknet via helm..."
  helm repo add chaos-mesh https://charts.chaos-mesh.org
  helm install chaos-mesh chaos-mesh/chaos-mesh -n=chaos-mesh --version 2.6.3 --set dashboard.securityMode=false --set bpfki.create=true
  echo "Attacknet is installed."

  # port forward the dashboard
  echo "Use the following command to access the dashboard:
    kubectl --namespace chaos-mesh port-forward svc/chaos-dashboard 2333
  "

  # Possible attack scenarios
  echo "To test some attack scenarios:
  1. Memory stress attack: \`start_attack_scenario metaclear-memory-stress <path_to_attacknet_folder>\`
  2. Bandwith attack: \`start_attack_scenario metaclear-network-bandwidth <path_to_attacknet_folder>\`
  3. Clock skew attack: \`start_attack_scenario metaclear-clock-skew <path_to_attacknet_folder>\`
  "
}

start_attack_scenario() {
  local attack_scenario=$1
  local attacknet_path="${2:-"./Documents/attacknet"}"
  local current_dir=$(pwd)
  # go to attacknet directory
  echo "Go to attacknet directory $attacknet_path..."
  cd "$attacknet_path"

  echo "Launch attack scenario $attack_scenario..."
  attacknet start $attack_scenario

  echo "Back to current directory $current_dir..."
  cd "$current_dir"
}
