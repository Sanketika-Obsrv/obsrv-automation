#!/bin/bash

# Function to check if a command is available
check_command() {
    command -v "$1" > /dev/null 2>&1
}

# Function to install a tool
install_tool() {
    local tool_name="$1"
    local install_command="$2"
    local version_command="$3"

    echo "Installing $tool_name..."
    eval "$install_command"

    # Check if the installation was successful
    if [ $? -eq 0 ]; then
        echo "$tool_name installed successfully."
        if [ -n "$version_command" ]; then
            installed_version=$(eval "$version_command")
            echo "Version: $installed_version"
        fi
    else
        echo "Error: Failed to install $tool_name. Please install it manually before proceeding."
        exit 1
    fi
}

# Validate and install required tools
validate_tools() {
    # Check for required tools
    tools=("aws" "terraform" "terrahelp" "terragrunt" "kubectl")

    for tool in "${tools[@]}"; do
        if ! check_command "$tool"; then
            echo "$tool not found. Do you want to install $tool? (yes/no)"
            read -r response

            if [ "$response" == "yes" ]; then
                case $tool in
                    "aws")
                        install_tool "$tool" 'curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && unzip awscliv2.zip && ./aws/install && rm -rf awscliv2.zip aws' 'aws --version'
                        ;;
                    "terraform")
                        install_tool "$tool" 'curl "https://releases.hashicorp.com/terraform/1.5.2/terraform_1.5.2_linux_amd64.zip" -o "terraform.zip" && unzip terraform.zip && mv terraform /usr/local/bin/ && rm terraform.zip' 'terraform --version'
                        ;;
                    "terrahelp")
                        install_tool "$tool" 'curl -OL https://github.com/opencredo/terrahelp/releases/download/v0.4.3/terrahelp-linux-amd64 && mv terrahelp-linux-amd64 /usr/local/bin/terrahelp && chmod +x /usr/local/bin/terrahelp' 'terrahelp --version'
                        ;;
                    "terragrunt")
                        install_tool "$tool" 'curl -OL https://github.com/gruntwork-io/terragrunt/releases/download/v0.45.8/terragrunt_linux_amd64 && mv terragrunt_linux_amd64 /usr/local/bin/terragrunt && chmod +x /usr/local/bin/terragrunt' 'terragrunt --version'
                        ;;
                    "kubectl")
                        install_tool "$tool" 'curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && mv kubectl /usr/local/bin/kubectl && chmod +x /usr/local/bin/kubectl' 'kubectl version --client --short'
                        ;;
                esac
            else
                echo "Please install $tool before proceeding."
                exit 1
            fi
        fi
    done

    echo "All required tools are installed. Proceeding with the rest of the script..."
    # Continue with the rest of your script...
}

# Kube_config directory setup and takes the backup of existing kubeconfig if exists
setup_kube_config() {
    kube_config_path=$KUBE_CONFIG_PATH 
    config_file="$kube_config_path/config"

    # Check if the ~/.kube directory exists
    if [ ! -d "$kube_config_path" ]; then
        mkdir -p "$kube_config_path"
        echo "Created $kube_config_path directory."
    fi

    if [ -e "$config_file" ]; then
        backup_file="$kube_config_path/config_backup_$(date +'%Y%m%d%H%M%S').bak"
        cp "$config_file" "$backup_file"
        echo "Backup created: $backup_file"
    else
        touch "$config_file"
        echo "Created an empty config file: $config_file"
    fi
}

# Check if the config file is provided as a command-line argument
if [ $# -eq 0 ]; then
    echo "Usage: $0 <config_file>"
    exit 1
fi

# Store the configuration file path
config_file="$1"

# Check if the config file exists
if [ ! -f "$config_file" ]; then
    echo "Error: Config file '$config_file' not found."
    exit 1
fi

# Read and set variables from the config file
source "$config_file"

# Set up AWS environment variables
echo "Setup Infa configurations"
export AWS_TERRAFORM_BACKEND_BUCKET_NAME=$AWS_TERRAFORM_BACKEND_BUCKET_NAME
export AWS_TERRAFORM_BACKEND_BUCKET_REGION=$AWS_TERRAFORM_BACKEND_BUCKET_REGION
export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION
export KUBE_CONFIG_PATH=$KUBE_CONFIG_PATH
setup_kube_config

# Validate and install required tools
validate_tools
