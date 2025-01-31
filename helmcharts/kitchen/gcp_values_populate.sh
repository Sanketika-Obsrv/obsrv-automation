!/bin/bash

if [ -z "$GOOGLE_PROJECT_ID" ]; then
  echo "GOOGLE_PROJECT_ID is not set"
  exit 1
fi

if [ -z "$GOOGLE_CLUSTER_REGION" ]; then
  echo "GOOGLE_CLUSTER_REGION is not set"
  exit 1
fi

if [ -z "$BUILDING_BLOCK" ]; then
  echo "BUILDING_BLOCK is not set"
  exit 1
fi

if [ -z "$BUILDING_BLOCK_ENV" ]; then
  echo "BUILDING_BLOCK_ENV is not set"
  exit 1
fi

if [ -z "$DATASET_API_CRED_FILE_PATH" ]; then
  echo "DATASET_API_CRED_FILE_PATH is not set"
  exit 1
fi

echo "Replacing Values in ../global-cloud-values-gcp.yaml"

echo "GOOGLE_PROJECT_ID: $GOOGLE_PROJECT_ID"
echo "GOOGLE_CLUSTER_REGION: $GOOGLE_CLUSTER_REGION"
echo "BUILDING_BLOCK: $BUILDING_BLOCK"
echo "BUILDING_BLOCK_ENV: $BUILDING_BLOCK_ENV"
echo "DATASET_API_CRED_FILE_PATH: $DATASET_API_CRED_FILE_PATH"

project_number=$(gcloud projects describe "$GOOGLE_PROJECT_ID" --format="value(projectNumber)")
if [ -z "$project_number" ]; then
  echo "Failed to get project number for project $GOOGLE_PROJECT_ID"
  exit 1
else
  echo "GOOGLE PROJECT NUMBER: $project_number"
fi

if [ -z jq ]; then
  echo "jq is not installed. Please install jq"
  exit 1
fi

dataset_api_client_email=$(jq -r '.client_email' "$DATASET_API_CRED_FILE_PATH")
if [ -z "$dataset_api_client_email" ]; then
  echo "Failed to get client_email from $DATASET_API_CRED_FILE_PATH"
  exit 1
else
  echo "DATASET API CLIENT EMAIL: $dataset_api_client_email"
fi

dataset_api_client_private_key=$(jq '.private_key' "$DATASET_API_CRED_FILE_PATH")
if [ -z "$dataset_api_client_private_key" ]; then
  echo "Failed to get private_key from $DATASET_API_CRED_FILE_PATH"
  exit 1
else
  echo "DATASET API CLIENT PRIVATE KEY: $dataset_api_client_private_key"
fi

set -x

sed -i "" "s/<replace_with_project_id>/$GOOGLE_PROJECT_ID/g" ../global-cloud-values-gcp.yaml
sed -i "" "s/<replace_with_project_num>/$project_number/g" ../global-cloud-values-gcp.yaml
sed -i "" "s/<replace_with_region>/$GOOGLE_CLUSTER_REGION/g" ../global-cloud-values-gcp.yaml
sed -i "" "s/<replace_with_building_block>/$BUILDING_BLOCK/g" ../global-cloud-values-gcp.yaml
sed -i "" "s/<replace_with_env>/$BUILDING_BLOCK_ENV/g" ../global-cloud-values-gcp.yaml
sed -i "" "s/<replace_with_client_email>/$dataset_api_client_email/g" ../global-cloud-values-gcp.yaml
sed -i "" "s/<replace_with_private_key>/$(echo "$dataset_api_client_private_key" | sed 's/[&/\]/\\&/g')/g" ../global-cloud-values-gcp.yaml
