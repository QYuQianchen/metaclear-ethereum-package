# Metaclear MEV-Boost Testnet
Please refer to the original [github.com/ethpandaops/ethereum-package](https://github.com/ethpandaops/ethereum-package) for detailed explanation of each paramter.


## Installation
1. Follow the installation guide on [ethpandaops/ethereum-package](https://github.com/ethpandaops/ethereum-package)
2. Install docker, kubectl, and minikube and follow the steps to configure the setup as in the [guide to running Kurtosis in Kubernetes](https://docs.kurtosis.com/k8s/)
3. Configure the image pull policy in Kubernetes so that it does not always pull from remote `imagePullPolicy: IfNotPresent`
3. Pull the repos and build their images locally
  - [metaclear-mev-relayer](https://github.com/QYuQianchen/metaclear-flashbot-relay)
  - [metaclear-lighthouse](https://github.com/QYuQianchen/metaclear-lighthouse)
  - [metaclear-attacknet](https://github.com/QYuQianchen/metaclear-attacknet)
4. Upload images to minikube
5. Run the launch script
  ```bash
    chmod +x ./launch.sh && ./launch.sh
  ```
