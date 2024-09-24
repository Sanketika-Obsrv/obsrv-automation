**Azure**
### Prerequisites:
* Log into your cloud environment in your terminal. Please see [Sign in with Azure CLI](https://learn.microsoft.com/en-us/cli/azure/authenticate-azure-cli) for reference.
    ```
    az login
    ```
* Create a storage account and export the below variables in your terminal. Please see [Create a storage container](https://learn.microsoft.com/en-us/azure/storage/common/storage-account-create?toc=/azure/storage/blobs/toc.json) for reference. Export the below variables in your terminal session
    ```
    export AZURE_TERRAFORM_BACKEND_RG=myregion
    export AZURE_TERRAFORM_BACKEND_STORAGE_ACCOUNT=mystorage
    export AZURE_TERRAFORM_BACKEND_CONTAINER=mycontainer
    ```
### Steps to install Obsrv:
* Execute the below commands in the same terminal session:
    ```
    cd terraform/azure
    ```
* Pass the below environment variables when prompted and execute the below commands:
    - Note: The below variable values are give for example
    ```
    env = dev
    building_block = obsrv
    location = EAST US 2
    terragrunt init
    terragrunt apply -target module.aks -auto-approve
    ```

* Export kubeconfig file and kubeconfig file path
    - The kubeconfig file is stored in current directory
    ```
    export KUBECONFIG=<path_to_kubeconfig>
    export KUBE_CONFIG_PATH=<path_to_kubeconfig>
    ```

* Execute the below commands in the same terminal session:
    ```
    terragrunt apply -target module.unified_helm -auto-approve
    kubectl get ingress superset -n superset
    ```
* Replace the ingress ip in terraform variables:
    ```
    web_console_base_url
    superset_base_url
    ```
* Execute the below commands in the same terminal session:
    ```
    terragrunt apply -target module.unified_helm -auto-approve
    ```
### Deployment using helm (Discontinued):
```
cd terraform/modules/helm/unified_helm

- Get the storage account name, storage account key, storage account container from azure portal

helm upgrade --install obsrv .  --namespace obsrv --create-namespace --set "global.            azure_storage_account_name=<storage account name>" --set "global.azure_storage_account_key=<storage account key>" --set "global.azure_storage_container=<storage container>"  –set “global.web_console_base_url=https://<ingress_ip>” –set “global.superset_base_url=https://<ingress_ip>” --atomic --timeout 1800s --debug

Get the ingress ip (kubectl get ingress superset -n superset)

helm upgrade --install obsrv .  --namespace obsrv --create-namespace --set "global.azure_storage_account_name=<storage account name>" --set "global.azure_storage_account_key=<storage account key>" --set "global.azure_storage_container=<storage container>"  –set “global.web_console_base_url=https://<ingress_ip>” –set “global.superset_base_url=https://<ingress_ip>” --atomic --timeout 1800s --debug
```
Note: Get the `storage account name`, `storage account key`, `storage account container` from portal here -
```
https://portal.azure.com/#@sanketika.in/resource/subscriptions/<subscription-id>/resourceGroups/<resource-group-name>
```
- Make a note of Resource Group created during the cluster creation. Usually it is a combination of `<building_block>-<env>`
- You can look for the logs for the statement like below to get the resource group
```
module.network.azurerm_resource_group.rg: Creation complete after 3s [id=/subscriptions/<uuid>/resourceGroups/<your-resource-group>]
```

### Steps to uninstall Obsrv:
* Execute the below commands:
    ```
    helm uninstall obsrv -n obsrv
    kubectl edit druid -n druid-raw
    ```
    - In the YAML editor, locate lines 12-13.
    - Delete any finalizers present in those lines
    - Save the changes
    ```
    terragrunt destroy -auto-approve
    ```
    - Pass the following variables when prompted
    ```
    env = dev
    building_block = obsrv
    location = EAST US 2
    ```