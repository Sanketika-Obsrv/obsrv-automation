
# Obsrv Infrastructure Setup Instructions

## Configuration

Define the necessary configurations in the `setup.conf` file:

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

Before executing the `setup` shell script, ensure that the `curl` and `unzip` utilities are present on your system. If they are not installed, you can use the following commands to install them. Execute the provided `setup.sh`` script as a root user to avoid potential permission issues:

**Prerequisites**
```bash
sudo apt-get update
sudo apt-get install -y curl
sudo apt-get install -y unzip
```

Once the `curl` and `unzip` utility is successfully installed, proceed with the setup by running the following command:

```bash
sh setup.sh ./setup.conf
```

This command utilizes the configurations specified in the `setup.conf` file to initiate the setup process.

