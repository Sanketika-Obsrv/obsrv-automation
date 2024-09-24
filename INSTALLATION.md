## Installation
To install Obsrv, you will need to clone the [Obsrv Automation](https://github.com/Sunbird-Obsrv/obsrv-automation) repository. It provides support for installation across major cloud providers. Please check [here](#configurations) for all the various configurations across all components.

You will require `terragrunt` to install Obsrv components. Please see [Install Terragrunt](https://terragrunt.gruntwork.io/docs/getting-started/install/) for installation help.
**AWS**
Prerequisites:
- You will need a `key-secret` pair to access AWS. Learn how to create or manage these at [Managing access keys for IAM users](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html). Please export these variables in terminal session.
    ```
    export AWS_ACCESS_KEY_ID=mykey
    export AWS_SECRET_ACCESS_KEY=mysecret
    ```
- You will require an S3 bucket to store tf-state. Learn how to create or manage these at [Create an Amazon S3 bucket](https://docs.aws.amazon.com/transfer/latest/userguide/requirements-S3.html). Please export this variable at
    ```
    export AWS_TERRAFORM_BACKEND_BUCKET_NAME=mybucket
    export AWS_TERRAFORM_BACKEND_BUCKET_REGION=myregion
    ```
- You will need `velero cli` to create the cluster backups. Learn how to install velero cli at ([Velero cli](https://velero.io/docs/v1.3.0/velero-install/))

#### Steps:
* Execute the below steps in the same terminal session:
    ```
    export KUBE_CONFIG_PATH=~/.kube/config
    cd terraform/aws
    terragrunt init
    terrahelp decrypt  -simple-key=<decryption_key> -file=vars/dev.tfvars
    terragrunt apply -target=module.eks -var-file=vars/cluster_overrides.tfvars -var-file=vars/dev.tfvars -auto-approve
    terragrunt apply -target=module.get_kubeconfig -var-file=vars/cluster_overrides.tfvars -var-file=vars/dev.tfvars -auto-approve
    terragrunt apply -var-file=vars/cluster_overrides.tfvars -var-file=vars/dev.tfvars -auto-approve
    ```
    Make necessary configuration changes to vars/cluster_overrides.tfvars file:
    - Modify values like env and building block and region. It is deployed in `us-east-2` by default

* Create a velero backup:
    - After the cluster is created velero backup needs to be triggered manually
    - We need to create a backup and schedule manually
    - Run the below commands to create a backup and schedule
        ```bash
        velero backup create <backup_name>
        velero backup schedule <backup_schedule_name>
        ```
    - Below example Creates a backup and schedule it for every 24h and retain the backup for 50h
        ```bash
        velero backup create obsrv-dev-full-cluster-backup
        velero backup schedule obsrv-dev-full-cluster-daily-backup --schedule="@every 24h" --ttl 50h0m0s
        ```


#### Tip:
Add `-auto-approve` to the above `terragrunt` command to install without providing user inputs as shown below
```
terragrunt apply -target=module.eks -var-file=vars/cluster_overrides.tfvars -var-file=vars/dev.tfvars -auto-approve && terragrunt apply -var-file=vars/cluster_overrides.tfvars -var-file=vars/dev.tfvars -target=module.get_kubeconfig -auto-approve && terragrunt apply -var-file=vars/cluster_overrides.tfvars -var-file=vars/dev.tfvars -auto-approve
```

*** GCP ***
### Prerequisites:
1. Setup the gcoud CLI. Please see [Installing Google Cloud SDK](https://cloud.google.com/sdk/docs/install) for reference.
2. Initialize and Authenticate the gcloud CLI. Please see [Initializing Cloud SDK](https://cloud.google.com/sdk/docs/initializing) for reference.

```
gcloud init
gcloud auth application-default login
```

3. Install additional dependencies to authenticate with GKE. Please see [Installing the gke-gcloud-auth-plugin](https://cloud.google.com/kubernetes-engine/docs/how-to/cluster-access-for-kubectl) for reference.

```
gcloud components install gke-gcloud-auth-plugin
```

4. Create a project and export it as variable. Please see [Creating and Managing Projects](https://cloud.google.com/resource-manager/docs/creating-managing-projects) for reference.

```
export GOOGLE_PROJECT_ID=myproject
GOOGLE_TERRAFORM_BACKEND_LOCATION=mylocation
export GOOGLE_TERRAFORM_BACKEND_BUCKET=mybucket
```

5. Enable the Kubernets Engine API for the created project. Please see [Enabling the Kubernetes Engine API](https://cloud.google.com/kubernetes-engine/docs/how-to/creating-a-zonal-cluster#enable-api) for reference.


6. Update the `terraform/gcp/vars/cluster_overrides.tfvars` file with the necessary values.


### Steps:
In order to complete the installation, please run the below steps in the same terminal.
```
cd terraform/gcp
terragrunt init
terrahelp decrypt -simple-key=<decryption_key> -file=vars/dev.tfvars
terragrunt plan --var-file=vars/cluster_overrides.tfvars --var-file=vars/dev.tfvars
terragrunt apply --var-file=vars/cluster_overrides.tfvars --var-file=vars/dev.tfvars
```

7. Set `KUBECONFIG` variable in your environment to point to the kubeconfig file.

```
export KUBECONFIG=$(pwd)/credentials/config-<building_block>-<env>.yaml
```


6. Navigate to `helmcharts` directory under the root diretory

```
cd ../../helmcharts/kitchen
```

7. Update the `global-cloud-values-gcp.yaml` file with the necessary values. The values to be updated are:
```
project_id:
cloud_storage_config:
cloud_storage_region:
cloud_storage_bucket:
postgresql_backup_cloud_bucket:
checkpoint_bucket:
redis_backup_cloud_bucket:
velero_backup_cloud_bucket:

serviceAccounts:
    -- update project_id in each service account
```

8. Run the below command to install the helm charts

```
cd kitchen/
CLOUD_ENV=gcp bash install.sh bootstrap
CLOUD_ENV=gcp bash install.sh coredb
```

9. Get the IP address of the LoadBalancer Service by Kong

```
kubectl get svc -n kong-ingress
```

10. Update `../global-values.yaml` with the domain as `<ip>.sslip.io` or a complete domain name if DNS is mapped

11. Follow the steps to complete the installation

```
bash install.sh migrations
bash install.sh monitoring
bash install.sh coreinfra
bash install.sh obsrvtools
bash install.sh additional
```

12. Check if the ingress routes are created

```
kubectl get ingress -A
```

13. Navigate to <domain>/console to access the web console


**Azure**
### Prerequisites:
* Log into your cloud environment in your terminal. Please see [Sign in with Azure CLI](https://learn.microsoft.com/en-us/cli/azure/authenticate-azure-cli) for reference.
    ``` bash
    az login --allow-no-subscriptions
    ```
* Create a storage account and export the below variables in your terminal. Please see [Create a storage container](https://learn.microsoft.com/en-us/azure/storage/common/storage-account-create?toc=/azure/storage/blobs/toc.json) for reference. Export the below variables in your terminal session
    ```
    export AZURE_TERRAFORM_BACKEND_RG=myregion
    export AZURE_TERRAFORM_BACKEND_STORAGE_ACCOUNT=mystorage
    export AZURE_TERRAFORM_BACKEND_CONTAINER=mycontainer
    ```
### Steps:
* Execute the below commands in the same terminal session:
    ```bash
    cd terraform/azure
    terragrunt init
    terragrunt apply -target module.aks -auto-approve
    ```
* Pass the following variables when prompted:
    ```bash
    env: dev
    building_block: obsrv
    location: East US 2
    ```
- Note:  All the above variable values are given for example
* Export the below variables:
    ``` bash
    export KUBE_CONFIG_PATH=<path_to_kubeconfig>( default to current directory)
    export KUBECONFIG=<path_to_kubeconfig>( default to current directory)
    ```
* Execute the below commands in the same terminal session:
    ``` bash
    terragrunt apply -auto-approve
    kubectl get ingress superset -n superset
    ```
* Pass the following variables when prompted:
    ```bash
    env: dev
    building_block: obsrv
    location: East US 2
    ```
- Note:  All the above variable values are given for example
* Replace the ingress ip in terraform variables:
    ```
    web_console_base_url
    superset_base_url
    ```
* Execute the below commands in the same terminal session:
    ```
    terragrunt apply -target module.unified_helm -auto-approve
    ```
* Pass the following variables when prompted:
    ```bash
    env: dev
    building_block: obsrv
    location: East US 2
    ```
- Note:  All the above variable values are given for example