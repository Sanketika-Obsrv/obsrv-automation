**Azure**

## Phase 1 — Admin setup (run once, requires subscription-level access)

An admin with Azure subscription access runs the setup script to create an installer VM with a
user-assigned managed identity. The managed identity gets the RBAC roles needed to deploy OBSRV.
No storage-account keys are needed at any point.

The script creates:
- Installer resource group (VM, identity, Terraform backend storage)
- OBSRV resource group
- OBSRV data storage account
- Terraform backend storage account and container
- Installer VM with the managed identity attached
- `obsrv-azure-env.sh` — env file to source on the VM

```bash
chmod +x terraform/azure/setup-azure-installer-identity.sh

export SUBSCRIPTION_ID="<subscription-id>"
export OBSRV_STORAGE_ACCOUNT_NAME="<globally-unique-storage-name>"   # 3-24 chars, lowercase/digits

# Optional overrides (defaults shown):
# export RESOURCE_GROUP="obsrv-installer-rg"
# export OBSRV_RESOURCE_GROUP="obsrv-dev"
# export OBSRV_ENV="dev"
# export LOCATION="eastus2"
# export VM_NAME="obsrv-installer-vm"
# export IDENTITY_NAME="obsrv-installer-identity"

./terraform/azure/setup-azure-installer-identity.sh
```

The script grants `Contributor` and `User Access Administrator` at subscription scope, and
`Storage Blob Data Contributor` on both storage accounts. Adjust roles to match your
organization's policy.

After the script finishes, copy the generated env file to the installer VM:

```bash
scp obsrv-azure-env.sh azureuser@<vm-ip>:~/
```

---

## Phase 2 — Install OBSRV (run from the installer VM)

SSH into the VM created in Phase 1:

```bash
ssh azureuser@<vm-ip>
```

Log in using the managed identity (no password or key required):

```bash
az login --identity
```

Source the env file to configure the Terraform backend:

```bash
source ~/obsrv-azure-env.sh
```

Clone the repository and configure the deployment:

```bash
git clone https://github.com/Sunbird-Obsrv/obsrv-automation.git
cd obsrv-automation/terraform/azure
```

Edit `vars/cluster_overrides.tfvars` and set at minimum:

```hcl
env                      = "dev"
building_block           = "obsrv"
location                 = "eastus2"
resource_group_name      = "obsrv-dev"               # must match OBSRV_RESOURCE_GROUP from Phase 1
storage_account_name     = "<OBSRV_STORAGE_ACCOUNT_NAME>"  # must match Phase 1

# Authentication — choose one:
# Option A — managed identity (recommended, no key needed):
#   Leave azure_storage_account_key commented out or set to "".
#   Terraform reads the key automatically via the managed identity.
#   Requires: Contributor role on the subscription (granted by setup script).
#
# Option B — storage account key:
#   Uncomment and set the key. Managed identity not required for storage access.
#   azure_storage_account_key = "<key from Azure portal or: az storage account keys list ...>"
```

### Steps to install Obsrv:

```bash
cd terraform/azure
terragrunt init
terragrunt apply -target module.aks -auto-approve
```

Export kubeconfig (the file is written to the current directory by Terraform):

```bash
export KUBECONFIG=$(pwd)/obsrv-dev-kubeconfig.yaml   # filename is <building_block>-<env>-kubeconfig.yaml
export KUBE_CONFIG_PATH=$KUBECONFIG
```

Deploy the platform:

```bash
terragrunt apply -target module.unified_helm -auto-approve
kubectl get ingress superset -n superset
```

Update `web_console_base_url` and `superset_base_url` in `vars/cluster_overrides.tfvars` with the
ingress IP, then re-apply:

```bash
terragrunt apply -target module.unified_helm -auto-approve
```

> **Storage account key**: Terraform reads the storage account key automatically via the managed
> identity (using the `azurerm_storage_account` data source in `main.tf`). You do not need to
> look up or paste the key manually.

---

### Service principal (alternative to managed identity)

If you prefer a service principal instead of a managed identity, sign in with:

```bash
az login --service-principal -u <app-id> -p <client-secret> --tenant <tenant-id>
```

Grant the service principal the same roles listed in Phase 1 (`Contributor`,
`User Access Administrator`, `Storage Blob Data Contributor`).

---

### Deployment using helm (Discontinued)

```
cd terraform/modules/helm/unified_helm

helm upgrade --install obsrv .  --namespace obsrv --create-namespace \
  --set "global.azure_storage_account_name=<storage account name>" \
  --set "global.azure_storage_account_key=<storage account key>" \
  --set "global.azure_storage_container=<storage container>" \
  --set "global.web_console_base_url=https://<ingress_ip>" \
  --set "global.superset_base_url=https://<ingress_ip>" \
  --atomic --timeout 1800s --debug
```

---

### Steps to uninstall Obsrv:

```bash
helm uninstall obsrv -n obsrv
kubectl edit druid -n druid-raw
```

In the YAML editor, locate lines 12-13, delete any finalizers, then save.

```bash
terragrunt destroy -auto-approve
```

Pass the following variables when prompted:

```
env            = dev
building_block = obsrv
location       = eastus2
```
