#!/usr/bin/env bash
set -euo pipefail

# Admin helper: prepare a VM with a user-assigned managed identity that holds the
# RBAC roles required to deploy OBSRV — no storage-account keys needed.
#
# Run this once from any machine that has 'az' CLI and subscription-level access.
# The script creates:
#   - Installer resource group (for VM, managed identity, Terraform backend storage)
#   - User-assigned managed identity with required roles
#   - Terraform backend storage account + container
#   - OBSRV data storage account
#   - Installer VM with the managed identity attached
#   - obsrv-azure-env.sh — source this on the VM before running terragrunt
#
# Required env vars:
#   SUBSCRIPTION_ID              Azure subscription ID
#   OBSRV_STORAGE_ACCOUNT_NAME   Storage account name for OBSRV data (globally unique, 3-24 chars)
#
# Optional env vars (defaults shown):
#   RESOURCE_GROUP               obsrv-installer-rg
#   OBSRV_RESOURCE_GROUP         obsrv-<env> — set if you want a custom name
#   OBSRV_ENV                    dev
#   LOCATION                     eastus2
#   VM_NAME                      obsrv-installer-vm
#   IDENTITY_NAME                obsrv-installer-identity
#   BACKEND_STORAGE_ACCOUNT_NAME obsrvtfstate<sub-prefix>
#   BACKEND_CONTAINER_NAME       tfstate
#   ADMIN_USERNAME               azureuser
#   SSH_PUBLIC_KEY_PATH          ~/.ssh/id_rsa.pub
#
# Usage:
#   export SUBSCRIPTION_ID="<subscription-id>"
#   export OBSRV_STORAGE_ACCOUNT_NAME="<globally-unique-name>"
#   chmod +x terraform/azure/setup-azure-installer-identity.sh
#   ./terraform/azure/setup-azure-installer-identity.sh

SUBSCRIPTION_ID="${SUBSCRIPTION_ID:-}"
OBSRV_STORAGE_ACCOUNT_NAME="${OBSRV_STORAGE_ACCOUNT_NAME:-}"
OBSRV_ENV="${OBSRV_ENV:-dev}"
RESOURCE_GROUP="${RESOURCE_GROUP:-obsrv-installer-rg}"
OBSRV_RESOURCE_GROUP="${OBSRV_RESOURCE_GROUP:-obsrv-${OBSRV_ENV}}"
LOCATION="${LOCATION:-eastus2}"
VM_NAME="${VM_NAME:-obsrv-installer-vm}"
IDENTITY_NAME="${IDENTITY_NAME:-obsrv-installer-identity}"
ADMIN_USERNAME="${ADMIN_USERNAME:-azureuser}"
SSH_PUBLIC_KEY_PATH="${SSH_PUBLIC_KEY_PATH:-$HOME/.ssh/id_rsa.pub}"
BACKEND_CONTAINER_NAME="${BACKEND_CONTAINER_NAME:-tfstate}"

if [[ -z "$SUBSCRIPTION_ID" ]]; then
  echo "ERROR: Set SUBSCRIPTION_ID before running this script."
  exit 1
fi

if [[ -z "$OBSRV_STORAGE_ACCOUNT_NAME" ]]; then
  echo "ERROR: Set OBSRV_STORAGE_ACCOUNT_NAME (storage account for OBSRV data, globally unique)."
  exit 1
fi

# Derive a short unique suffix from the subscription ID for the backend storage account
SUB_PREFIX="$(echo "$SUBSCRIPTION_ID" | tr -d '-' | cut -c1-8)"
BACKEND_STORAGE_ACCOUNT_NAME="${BACKEND_STORAGE_ACCOUNT_NAME:-obsrvtf${SUB_PREFIX}}"

if [[ ! -f "$SSH_PUBLIC_KEY_PATH" ]]; then
  echo "Generating SSH key pair at $HOME/.ssh/id_rsa..."
  ssh-keygen -t rsa -b 2048 -f "$HOME/.ssh/id_rsa" -N ""
fi

az account set --subscription "$SUBSCRIPTION_ID"

# ---------- installer resource group ----------
echo "Creating installer resource group $RESOURCE_GROUP in $LOCATION..."
az group create --name "$RESOURCE_GROUP" --location "$LOCATION" >/dev/null

# ---------- obsrv resource group ----------
echo "Creating OBSRV resource group $OBSRV_RESOURCE_GROUP in $LOCATION..."
az group create --name "$OBSRV_RESOURCE_GROUP" --location "$LOCATION" >/dev/null

# ---------- managed identity ----------
echo "Creating user-assigned managed identity $IDENTITY_NAME..."
az identity create \
  --name "$IDENTITY_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" >/dev/null

IDENTITY_PRINCIPAL_ID="$(az identity show \
  --name "$IDENTITY_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query principalId -o tsv)"

IDENTITY_RESOURCE_ID="$(az identity show \
  --name "$IDENTITY_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query id -o tsv)"

SUBSCRIPTION_SCOPE="/subscriptions/$SUBSCRIPTION_ID"

# Role propagation in AAD can take a few seconds
echo "Waiting for identity to propagate..."
sleep 15

# ---------- RBAC roles ----------
echo "Assigning Contributor at subscription scope..."
az role assignment create \
  --assignee-object-id "$IDENTITY_PRINCIPAL_ID" \
  --assignee-principal-type ServicePrincipal \
  --role "Contributor" \
  --scope "$SUBSCRIPTION_SCOPE" >/dev/null

echo "Assigning User Access Administrator at subscription scope..."
az role assignment create \
  --assignee-object-id "$IDENTITY_PRINCIPAL_ID" \
  --assignee-principal-type ServicePrincipal \
  --role "User Access Administrator" \
  --scope "$SUBSCRIPTION_SCOPE" >/dev/null

# ---------- Terraform backend storage account ----------
echo "Creating Terraform backend storage account $BACKEND_STORAGE_ACCOUNT_NAME..."
az storage account create \
  --name "$BACKEND_STORAGE_ACCOUNT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --allow-blob-public-access false \
  --min-tls-version TLS1_2 >/dev/null

BACKEND_STORAGE_SCOPE="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Storage/storageAccounts/$BACKEND_STORAGE_ACCOUNT_NAME"
az role assignment create \
  --assignee-object-id "$IDENTITY_PRINCIPAL_ID" \
  --assignee-principal-type ServicePrincipal \
  --role "Storage Blob Data Contributor" \
  --scope "$BACKEND_STORAGE_SCOPE" >/dev/null

az storage container create \
  --name "$BACKEND_CONTAINER_NAME" \
  --account-name "$BACKEND_STORAGE_ACCOUNT_NAME" \
  --auth-mode login >/dev/null

# ---------- OBSRV data storage account ----------
echo "Creating OBSRV data storage account $OBSRV_STORAGE_ACCOUNT_NAME..."
az storage account create \
  --name "$OBSRV_STORAGE_ACCOUNT_NAME" \
  --resource-group "$OBSRV_RESOURCE_GROUP" \
  --location "$LOCATION" \
  --sku Standard_LRS \
  --kind StorageV2 \
  --allow-blob-public-access false \
  --min-tls-version TLS1_2 >/dev/null

OBSRV_STORAGE_SCOPE="/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$OBSRV_RESOURCE_GROUP/providers/Microsoft.Storage/storageAccounts/$OBSRV_STORAGE_ACCOUNT_NAME"
az role assignment create \
  --assignee-object-id "$IDENTITY_PRINCIPAL_ID" \
  --assignee-principal-type ServicePrincipal \
  --role "Storage Blob Data Contributor" \
  --scope "$OBSRV_STORAGE_SCOPE" >/dev/null

# ---------- installer VM ----------
echo "Creating installer VM $VM_NAME..."
az vm create \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VM_NAME" \
  --image Ubuntu2204 \
  --size Standard_B4ms \
  --admin-username "$ADMIN_USERNAME" \
  --ssh-key-values "$SSH_PUBLIC_KEY_PATH" \
  --assign-identity "$IDENTITY_RESOURCE_ID" \
  --enable-agent true >/dev/null

VM_PUBLIC_IP="$(az vm show \
  --resource-group "$RESOURCE_GROUP" \
  --name "$VM_NAME" \
  --show-details \
  --query publicIps -o tsv)"

# ---------- env file ----------
ENV_FILE="obsrv-azure-env.sh"
cat > "$ENV_FILE" <<EOF
# Source this file on the installer VM before running terragrunt.
# Generated by setup-azure-installer-identity.sh

export AZURE_TERRAFORM_BACKEND_RG="${RESOURCE_GROUP}"
export AZURE_TERRAFORM_BACKEND_STORAGE_ACCOUNT="${BACKEND_STORAGE_ACCOUNT_NAME}"
export AZURE_TERRAFORM_BACKEND_CONTAINER="${BACKEND_CONTAINER_NAME}"
EOF

echo
echo "======================================================"
echo " Setup complete"
echo "======================================================"
echo
echo "  Installer VM:          $VM_NAME  ($VM_PUBLIC_IP)"
echo "  Managed identity:      $IDENTITY_NAME"
echo "  Terraform backend:     $BACKEND_STORAGE_ACCOUNT_NAME / $BACKEND_CONTAINER_NAME"
echo "  OBSRV resource group:  $OBSRV_RESOURCE_GROUP"
echo "  OBSRV storage:         $OBSRV_STORAGE_ACCOUNT_NAME"
echo
echo "Next steps:"
echo
echo "  1. Copy env file to VM:"
echo "       scp $ENV_FILE $ADMIN_USERNAME@$VM_PUBLIC_IP:~/"
echo
echo "  2. SSH into the VM:"
echo "       ssh $ADMIN_USERNAME@$VM_PUBLIC_IP"
echo
echo "  3. On the VM — log in with managed identity and deploy OBSRV:"
echo "       az login --identity"
echo "       source ~/obsrv-azure-env.sh"
echo "       git clone https://github.com/Sunbird-Obsrv/obsrv-automation.git"
echo "       cd obsrv-automation/terraform/azure"
echo "       # Edit vars/cluster_overrides.tfvars and set:"
echo "       #   resource_group_name      = \"$OBSRV_RESOURCE_GROUP\""
echo "       #   storage_account_name     = \"$OBSRV_STORAGE_ACCOUNT_NAME\""
echo "       #   env                      = \"$OBSRV_ENV\""
echo "       terragrunt init"
echo "       terragrunt apply -target module.aks -auto-approve"
echo
