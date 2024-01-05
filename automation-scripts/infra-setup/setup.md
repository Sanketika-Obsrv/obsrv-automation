
# Infrastructure Setup Instructions

## Configuration

Define the necessary configurations in the `setup.conf` file:

### setup.conf

```bash
AWS_ACCESS_KEY_ID="access_key"
AWS_SECRET_ACCESS_KEY="secret_key"
AWS_DEFAULT_REGION="region"
KUBE_CONFIG_PATH="$HOME/.kube"
AWS_TERRAFORM_BACKEND_BUCKET_NAME="bucket_name"
AWS_TERRAFORM_BACKEND_BUCKET_REGION="region"

# Add more variables as needed
```

Replace placeholders (`access_key`, `secret_key`, `region`, `bucket_name`, etc.) with actual values.

## Tool Installation

Ensure the installation of the following tools:

| Tool        | Version    |
|-------------|------------|
| aws         | 2.13.8     |
| helm        | 3.50.2     |
| terraform   | 1.5.7      |
| terrahelp   | 0.7.5      |
| terragrunt  | 0.45.6     |

## Setup Process

Run the following command to initiate the setup:

```bash
sh setup.sh ./setup.conf
```

Update `setup.conf` with the correct configurations before running the script. Ensure the specified tool versions are installed.


