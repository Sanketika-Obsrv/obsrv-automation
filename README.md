# Obsrv Installation

### Prerequisites:
1. Install terragrunt. Please see [Install Terragrunt](https://terragrunt.gruntwork.io/docs/getting-started/install/) for reference.

## AWS
### Prerequisites:
1. You will need key-secret pair to access AWS. Learn how to create or manage these at [Managing access keys for IAM users](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html). Please export these variables in terminal session
```
export AWS_ACCESS_KEY_ID=mykey
export AWS_SECRET_ACCESS_KEY=mysecret
```
2. You will require an S3 bucket to store tf-state. Learn how to create or manage these at [Create an Amazon S3 bucket](https://docs.aws.amazon.com/transfer/latest/userguide/requirements-S3.html). Please export this variable at
```
export AWS_TERRAFORM_BACKEND_BUCKET_NAME=mybucket
export AWS_TERRAFORM_BACKEND_BUCKET_REGION=myregion
```
3. If you need to run your cluster in multiple availability zones, then please update below line in `terraform/aws/main.tf`
```
# default, single AZ
eks_nodes_subnet_ids  = module.vpc.single_zone_public_subnets_id
# Multiple AZ
eks_nodes_subnet_ids  = module.vpc.multi_zone_public_subnets_ids
```
### Steps:
In order to complete the installation, please run the below steps in the same terminal.
```
cd terraform/aws
terragrunt init
terragrunt plan
terragrunt apply
```
## GCP
### Prerequisites:
1. Setup the gcoud CLI. Please see [Installing Google Cloud SDK](https://cloud.google.com/sdk/docs/install) for reference.
2. Initialize and Authenticate the gcloud CLI. Please see [Initializing Cloud SDK](https://cloud.google.com/sdk/docs/initializing) for reference.

```
gcloud init
gcloud auth login
```

3. Install additional dependencies to authenticate with GKE. Please see [Installing the gke-gcloud-auth-plugin](https://cloud.google.com/kubernetes-engine/docs/how-to/cluster-access-for-kubectl) for reference.

```
gcloud components install gke-gcloud-auth-plugin
```

4. Create a project and export it as variable. Please see [Creating and Managing Projects](https://cloud.google.com/resource-manager/docs/creating-managing-projects) for reference.

```
export GOOGLE_CLOUD_PROJECT=myproject
export GOOGLE_TERRAFORM_BACKEND_BUCKET=mybucket
```

5. Enable the Kubernets Engine API for the created project. Please see [Enabling the Kubernetes Engine API](https://cloud.google.com/kubernetes-engine/docs/how-to/creating-a-zonal-cluster#enable-api) for reference.

### Steps:
In order to complete the installation, please run the below steps in the same terminal.
```
cd terraform/gcp
terragrunt init
terragrunt plan
terragrunt apply
```

## Azure
### Prerequisites:
1. Log into your cloud environment in your terminal. Please see [Sign in with Azure CLI](https://learn.microsoft.com/en-us/cli/azure/authenticate-azure-cli) for reference.
```
az login
```
2. Create a storage account and export the below variables in your terminal. Please see [Create a storage container](https://learn.microsoft.com/en-us/azure/storage/common/storage-account-create?toc=/azure/storage/blobs/toc.json) for reference. Export the below variables in your terminal session
```
export AZURE_TERRAFORM_BACKEND_RG=myregion
export AZURE_TERRAFORM_BACKEND_STORAGE_ACCOUNT=mystorage
export AZURE_TERRAFORM_BACKEND_CONTAINER=mycontainer
```
### Steps:
In order to complete the installation, please run the below steps in the same terminal.
```
cd terraform/azure
terragrunt init
terragrunt plan
terragrunt apply
```
