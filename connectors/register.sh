#!/bin/bash

dataset_api_port=3000

# function to check and install kubectl
install_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        echo "kubectl is not installed. Would you like to install kubectl? (yes/no)"
        read -r response
        if [ "$response" == "yes" ]; then

            ### Linux x86_64
            if [ "$(uname -s)" == "Linux" ] && [ "$(uname -m)" == "x86_64" ]; then
                echo "Installing kubectl..."
                   curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
                chmod +x kubectl
                sudo mv kubectl /usr/local/bin/
                echo "kubectl has been successfully installed."
            ## Linux arm64
            elif [ "$(uname -s)" == "Linux" ] && [ "$(uname -m)" == "aarch64" ]; then
                curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/arm64/kubectl"
                chmod +x kubectl
                sudo mv kubectl /usr/local/bin/
                echo "kubectl has been successfully installed."
            ## Mac
            elif [ "$(uname -s)" == "Darwin" ]; then
                curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/darwin/amd64/kubectl"
                chmod +x kubectl
                sudo mv kubectl /usr/local/bin/
                echo "kubectl has been successfully installed."
            else
                echo "Unable to detect supported OS. Please install kubectl manually and re-run the script."
                exit 1
            fi
        else
            echo "kubectl is required to proceed. Please install kubectl and re-run the script."
            exit 1
        fi
    else
        echo "kubectl is already installed."
    fi
}


check_kubeconfig() {
    if [ -z "$KUBECONFIG" ]; then
        echo "KUBECONFIG is not set and isrequired to proceed. Please set KUBECONFIG and re-run the script."
        exit 1
    else
        echo "Using KUBECONFIG from '$KUBECONFIG' and running with current-context: '$(kubectl config current-context)'"
    fi
}

check_dataset_installation(){
    dataset_api_pod=$(kubectl get pods -n dataset-api --selector app.kubernetes.io/name=dataset-api -o jsonpath='{.items[0].metadata.name}')

    # check if dataset api pod starts with dataset-api
    if [[ $dataset_api_pod == "dataset-api"* ]]; then
        echo "Dataset API is installed [$dataset_api_pod]"
    else
        echo "Dataset API is not installed. Please install Dataset API before proceeding."
        exit 1
    fi
}

open_dataset_api_ports(){
    echo "Opening ports for dataset api..."
    # generate random port number and see if its available
    while [ $dataset_api_port -lt 65535 ]; do
        if ! lsof -i:$dataset_api_port; then
            echo "Port $dataset_api_port is available."
            break
        else
            dataset_api_port=$((RANDOM % 65535))
        fi
    done

    # Open ports for dataset api in background
    kubectl port-forward -n dataset-api $dataset_api_pod $dataset_api_port:3000 &

    # Wait for port-forward to start
    number_of_tries=0
    while ! lsof -i:$dataset_api_port; do
        echo "Waiting for port-forward to start..."
        sleep 10
        number_of_tries=$((number_of_tries + 1))
        if [ $number_of_tries -eq 10 ]; then
            echo "Failed to start port-forward. Please check the logs and try again."
            exit 1
        fi
    done
    echo "Dataset API is now accessible at http://localhost:$dataset_api_port"
}

register_connectors() {
    # list all normal files in distributions directory
    for connector in $(ls -1 distributions/*.tar.gz); do
        echo "\nRegistering connector: $connector"
        curl --progress-bar --location "localhost:$dataset_api_port/v2/connector/register" \
        --header 'Content-Type: multipart/form-data' \
        --form "file=@$connector" | cat
        rm -rf $connector
    done
}

close_dataset_api_ports(){
    # Close port-forward
    kill $(lsof -t -i:$dataset_api_port)
    echo "Port-forward is closed."
}

install_kubectl
check_kubeconfig
check_dataset_installation
open_dataset_api_ports
register_connectors
close_dataset_api_ports

## Handle SIGINT and SIGTERM and close port-forward
trap 'close_dataset_api_ports' SIGINT SIGTERM