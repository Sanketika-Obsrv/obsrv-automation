
# Obsrv Infrastructure Setup Instructions

## Configuration

Define the necessary configurations in the `obsrv.conf` file:

### setup.conf

```bash
AWS_ACCESS_KEY_ID="$access_key"
AWS_SECRET_ACCESS_KEY="$secret_key"
AWS_DEFAULT_REGION="$region"
KUBE_CONFIG_PATH="$HOME/.kube"
AWS_TERRAFORM_BACKEND_BUCKET_NAME="$bucket_name"
AWS_TERRAFORM_BACKEND_BUCKET_REGION="$region"

# Add more variables as needed
```

Replace placeholders (`$access_key`, `$secret_key`, `$region`, `$bucket_name`, etc.) with actual values.

## Tool Installation

Ensure the installation of the following tools:

| Tool        | Version      |
|-------------|--------------|
| aws         | >=2.13.8     |
| helm        | >=3.10.2     |
| terraform   | >=1.5.7      |
| terrahelp   | >=0.7.5      |
| terragrunt  | >=0.45.6     |

## Setup Process

1. Run Installation Script: Execute the following command to start the installation process:
    - Before installing please provide executable permission to installation script
    `chmod +x ./obsrv.sh`
    ```bash
    ./obsrv.sh install --config ./obsrv.conf --install_dependencies false
    ```
    - Note: Setting install_dependencies=true will automatically download and install all required dependencies. If preferred, you can manually download the dependencies instead.
2. Monitor Installation Progress: The script will begin installing Obsrv within the AWS cluster. Monitor the progress and follow any on-screen prompts or instructions.

