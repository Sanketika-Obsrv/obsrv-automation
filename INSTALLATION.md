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

4. Create a project and pass values for these variable in `helmcharts/infra-setup/obsrv.conf`.

```
GOOGLE_PROJECT_ID=myproject
GOOGLE_TERRAFORM_BACKEND_LOCATION=mylocation
GOOGLE_TERRAFORM_BACKEND_BUCKET=mybucket
```

5. Enable the Kubernets Engine API for the created project. Please see [Enabling the Kubernetes Engine API](https://cloud.google.com/kubernetes-engine/docs/how-to/creating-a-zonal-cluster#enable-api) for reference.


6. Update the `terraform/gcp/vars/cluster_overrides.tfvars` file with the necessary values.


### Steps:
In order to complete the installation, please run the below cmd in the same terminal under `/infra-setup`.
```
time ./obsrv.sh install --provider gcp --config ./obsrv.conf
```

7. Set `KUBECONFIG` variable in your environment to point to the kubeconfig file. You will find the kubeconfig file under `terraform/gcp/` directory.

```
export KUBECONFIG=$(pwd)/credentials/config-<building_block>-<env>.yaml
```


6. Navigate to `helmcharts` directory under the root diretory

```
cd ../../helmcharts/kitchen
```

7. Update the `global-cloud-values-gcp.yaml` file with the necessary values. The values to be updated are(all the service accounts annotations should be updated in placeholders.):
```
project_id:
cloud_storage_config:
cloud_storage_region:
cloud_storage_bucket:
postgresql_backup_cloud_bucket:
checkpoint_bucket:
redis_backup_cloud_bucket: # currently we don't have this key in the global file.
velero_backup_cloud_bucket:

serviceAccounts:
    -- update project_id in each service account
```

8. Run the below command to install the helm charts

```
cd kitchen/
export cloud_env=gcp 
bash install.sh core-setup
```

9. Get the IP address of the LoadBalancer Service by Kong

```
kubectl get svc -n kong-ingress
```

10. Update `../global-values.yaml` with the domain as `<ip>.sslip.io` or a complete domain name if DNS is mapped

11. Follow this step to complete the installation.
```
bash install.sh all
```

12. Check if the ingress routes are created

```
kubectl get ingress -A
```

13. Navigate to <domain>/console to access the web console


**Azure**

See [AZURE_INSTALLATION.md](AZURE_INSTALLATION.md) for the full guide. Summary below.

### Phase 1 — Admin setup (run once, requires subscription-level access)

Run the setup script from any machine with `az` CLI and subscription-level access. It creates
the installer VM, managed identity, Terraform backend, and OBSRV storage account — no keys needed.

```bash
chmod +x terraform/azure/setup-azure-installer-identity.sh
export SUBSCRIPTION_ID="<subscription-id>"
export OBSRV_STORAGE_ACCOUNT_NAME="<globally-unique-storage-name>"
./terraform/azure/setup-azure-installer-identity.sh
```

Copy the generated `obsrv-azure-env.sh` to the VM:

```bash
scp obsrv-azure-env.sh azureuser@<vm-ip>:~/
```

### Phase 2 — Install OBSRV (run from the installer VM)

```bash
ssh azureuser@<vm-ip>
az login --identity
source ~/obsrv-azure-env.sh
git clone https://github.com/Sunbird-Obsrv/obsrv-automation.git
cd obsrv-automation/terraform/azure
# Edit vars/cluster_overrides.tfvars: set resource_group_name and storage_account_name
terragrunt init
terragrunt apply -target module.aks -auto-approve
export KUBECONFIG=$(pwd)/obsrv-dev-kubeconfig.yaml
export KUBE_CONFIG_PATH=$KUBECONFIG
terragrunt apply -target module.unified_helm -auto-approve
kubectl get ingress superset -n superset
# Update web_console_base_url and superset_base_url in vars/cluster_overrides.tfvars
terragrunt apply -target module.unified_helm -auto-approve
```

> Storage account key is read automatically by Terraform via the managed identity. No manual key lookup required.
