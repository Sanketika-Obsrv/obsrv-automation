#!/bin/bash

# Function to install Obsrv
install_obsrv() {
    echo "Obsrv installation has started.."
    terragrunt init
    terragrunt apply -target module.eks -var-file=vars/cluster_overrides.tfvars -auto-approve
    terragrunt apply -target module.get_kubeconfig -var-file=vars/cluster_overrides.tfvars -auto-approve
    terragrunt apply -var-file=vars/cluster_overrides.tfvars -auto-approve
    echo "Installation completed successfully!"
}

# Function to destroy Obsrv
destroy_obsrv() {
    echo "Destroying Obsrv..."
    terragrunt destroy -var-file=vars/cluster_overrides.tfvars -auto-approve
    echo "Obsrv has been successfully destroyed."
}

version_compare() {
    local version1="$1"
    local version2="$2"
    IFS='.' read v1_major v1_minor v1_patch <<< "$version1"
    IFS='.' read v2_major v2_minor v2_patch <<< "$version2"

    if [ "$v1_major" -gt "$v2_major" ] || [ "$v1_major" -eq "$v2_major" -a "$v1_minor" -gt "$v2_minor" ] || [ "$v1_major" -eq "$v2_major" -a "$v1_minor" -eq "$v2_minor" -a "$v1_patch" -ge "$v2_patch" ]; then
        echo true  
    else
        echo false
    fi
}

# Function to get installed version
get_installed_version() {
    local version_command="$1"
    if [ -n "$version_command" ]; then
        installed_version=$(eval "$version_command")
        echo "$installed_version"
    else
        echo "0.0.0" 
    fi
}


install_tool() {
    local tool_name="$1"
    local install_command="$2"
    local version_command="$3"
    local required_version="$4"

    installed_version=$(get_installed_version "$version_command")
    compare_result=$(version_compare "$installed_version" "$required_version")
    if [ "$compare_result" == "true" ]; then
        echo "$tool_name is already installed with supported version $installed_version"
        return
    else
        echo "$tool_name tool version $required_version is missing, but the installed version is $installed_version. Would you like to install the stable version of $tool_name? (yes/no)"
        read -r response

        if [ "$response" == "yes" ]; then
            echo "Installing $tool_name..."
            eval "$install_command"

            # Check if the installation was successful
            if [ $? -eq 0 ]; then
                echo "$tool_name installed successfully."
                if [ -n "$version_command" ]; then
                    installed_version=$(get_installed_version "$version_command")
                    echo "Version: $installed_version"
                fi
            else
                echo "Error: Failed to install $tool_name. Please install it manually before proceeding."
                exit 1
            fi
        else
            echo "Skipping installation of $tool_name."
        fi
    fi    
}

# Function to validate and install required tools
validate_and_install_tools() {
    # Define all the required tools with version
    tool_versions=(
        "aws:2.13.8"
        "helm:3.10.2"
        "terraform:1.5.7"
        "terrahelp:0.7.5"
        "terragrunt:0.45.6"
    )

    for tool_version in "${tool_versions[@]}"; do
        IFS=':' read -r tool required_version <<< "$tool_version"
        case $tool in
            "aws")
                aws_version="aws --version | awk 'NR==1{print \$1}' | cut -d'/' -f2"
                install_tool "$tool" 'curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && unzip awscliv2.zip && sudo ./aws/install -i /usr/local/aws-cli -b /usr/local/bin' "$aws_version" "$required_version"
                ;;
            "helm")
                helm_version="helm version --short | awk -F'[v+]' '/v/{print \$2}'"
                install_tool "$tool" 'curl https://get.helm.sh/helm-v3.10.2-linux-amd64.tar.gz -o helm.tar.gz && tar -zxvf helm.tar.gz && sudo mv linux-amd64/helm /usr/local/bin/' "$helm_version" "$required_version"
                ;;
            "terraform")
                terraform_version='terraform version | awk '\''/Terraform/{gsub(/[^0-9.]/, "", $2); print $2}'\'''
                install_tool "terraform" 'curl -LO "https://releases.hashicorp.com/terraform/1.5.7/terraform_1.5.7_linux_amd64.zip" -o "terraform.zip" && unzip terraform_1.5.7_linux_amd64.zip && sudo mv terraform /usr/local/bin/' "$terraform_version" "$required_version"
                ;;
            "terrahelp")
                terrahelp_version='terrahelp --version | awk '\''/terrahelp version/ {print $3}'\'''
                install_tool "$tool" 'curl -OL https://github.com/opencredo/terrahelp/releases/download/v0.4.3/terrahelp-linux-amd64 && mv terrahelp-linux-amd64 /usr/local/bin/terrahelp && chmod +x /usr/local/bin/terrahelp' "$terrahelp_version" "$required_version"
                ;;
            "terragrunt")
                terragrunt_version='terragrunt --version | awk '\''/terragrunt version/ {gsub(/v/, "", $3); print $3}'\'''
                install_tool "$tool" 'curl -OL https://github.com/gruntwork-io/terragrunt/releases/download/v0.45.8/terragrunt_linux_amd64 && mv terragrunt_linux_amd64 /usr/local/bin/terragrunt && chmod +x /usr/local/bin/terragrunt' "$terragrunt_version" "$required_version"
                ;;
        esac
    done

    echo "All required tools are installed. Proceeding with the rest of the script..."
}

# Main script
if [ $# -lt 1 ]; then
    echo "Usage: $0 [install|destroy] --config <config_file> [--install_dependencies true|false]"
    exit 1
fi

action=""
config_file=""
install_dependencies="false"

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        install|destroy)
            action="$1"
            ;;
        --config)
            config_file="$2"
            shift
            ;;
        --install_dependencies)
            install_dependencies="$2"
            shift
            ;;
        *)
            echo "Invalid option: $key"
            exit 1
            ;;
    esac
    shift
done

# Validate action
if [ -z "$action" ]; then
    echo "Error: Action (install/destroy) not specified."
    exit 1
fi

# Validate config file
if [ -z "$config_file" ]; then
    echo "Error: Config file not provided."
    exit 1
elif [ ! -f "$config_file" ]; then
    echo "Error: Config file '$config_file' not found."
    exit 1
fi

# Source the config file
source "$config_file" || { echo "Error: Failed to load $config_file."; exit 1; }

# Set up AWS environment variables
echo "Environment is updated with secrets"
export AWS_TERRAFORM_BACKEND_BUCKET_NAME=$AWS_TERRAFORM_BACKEND_BUCKET_NAME
export AWS_TERRAFORM_BACKEND_BUCKET_REGION=$AWS_TERRAFORM_BACKEND_BUCKET_REGION
export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION
export KUBE_CONFIG_PATH=$KUBE_CONFIG_PATH
export KUBECONFIG=$KUBE_CONFIG_PATH

# Install dependencies if required
if [[ "$install_dependencies" == "true" ]]; then
    validate_and_install_tools
fi

# Proceed with the specified action
cd ../../terraform/aws
case "$action" in
    install)
        install_obsrv
        ;;
    destroy)
        destroy_obsrv
        ;;
    *)
        echo "Invalid command. Usage: $0 [install|destroy] --config <config_file> [--install_dependencies true|false]"
        exit 1
        ;;
esac

