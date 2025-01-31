#!/bin/bash

# Configuration
PASSWORD_DIR="./passwords"  # Base directory to store passwords
STATE_FILE="$PASSWORD_DIR/state"  # File to track stored passwords

ENV_NAME=$1

# Ensure ENV_NAME is set
if [ -z "$ENV_NAME" ]; then
    echo "Error: ENV_NAME environment variable is not set."
    exit 1
fi

if [ -z jq ]; then
    echo "Error: jq is not installed. Please install jq."
    exit 1
fi

# Create password directory if it doesn't exist
mkdir -p "$PASSWORD_DIR"

# Generate a password function
generate_password() {
    local length=$1
    if [ -z "$length" ]; then
        length=$(( ( RANDOM % 21 ) + 12 ))
    fi
    # echo "Generating password of length $length"
    LC_ALL=C tr -dc 'A-Za-z0-9@#+' < /dev/urandom | head -c "$length"
}

# Path for the environment-specific password file
PASSWORD_FILE="$PASSWORD_DIR/$ENV_NAME.json"

# Check if password already exists
if [ -f "$PASSWORD_FILE" ]; then
    echo "Password for environment '$ENV_NAME' already exists:"
    cat "$PASSWORD_FILE"
else
    echo "{
        \"psql_super_user_password\": \"$(generate_password)\",
        \"psql_obsrv_user_password\": \"$(generate_password)\",
        \"psql_druid_user_password\": \"$(generate_password)\",
        \"psql_superset_user_password\": \"$(generate_password)\",
        \"psql_hms_user_password\": \"$(generate_password)\",
        \"psql_keycloak_user_password\": \"$(generate_password)\",
        \"grafana_admin_password\": \"$(generate_password)\",
        \"keycloak_admin_password\": \"$(generate_password)\",
        \"obsrv_password\": \"$(generate_password 12)\",
        \"superset_admin_password\": \"$(generate_password)\",
        \"encryption_key\": \"$(generate_password 32)\"
    }" > "$PASSWORD_FILE"

    cat "$PASSWORD_FILE"
fi

### Replace global-values.yaml with the new passwords
sed -i "" "s/pgpassword\ \"postgres\"/pgpassword\ \"$(jq -r '.psql_super_user_password' $PASSWORD_FILE)\"/g" ../global-values.yaml
sed -i "" "s/psql-obsrv-pwd\ \"obsrv123\"/psql-obsrv-pwd\ \"$(jq -r '.psql_obsrv_user_password' $PASSWORD_FILE)\"/g" ../global-values.yaml
sed -i "" "s/psql-druid-pwd\ \"druidraw123\"/psql-druid-pwd\ \"$(jq -r '.psql_druid_user_password' $PASSWORD_FILE)\"/g" ../global-values.yaml
sed -i "" "s/psql-superset-pwd\ \"superset123\"/psql-superset-pwd\ \"$(jq -r '.psql_superset_user_password' $PASSWORD_FILE)\"/g" ../global-values.yaml
sed -i "" "s/psql-hms-pwd\ \"hms123\"/psql-hms-pwd\ \"$(jq -r '.psql_hms_user_password' $PASSWORD_FILE)\"/g" ../global-values.yaml
sed -i "" "s/psql-keycloak-pwd\ \"keycloak123\"/psql-keycloak-pwd\ \"$(jq -r '.psql_keycloak_user_password' $PASSWORD_FILE)\"/g" ../global-values.yaml
sed -i "" "s/grafana-admin-password\ \"adminpassword\"/grafana-admin-password\ \"$(jq -r '.grafana_admin_password' $PASSWORD_FILE)\"/g" ../global-values.yaml
sed -i "" "s/keycloak_admin_password\ \"admin123\"/keycloak_admin_password\ \"$(jq -r '.keycloak_admin_password' $PASSWORD_FILE)\"/g" ../global-values.yaml
sed -i "" "s/obsrv_password\ \"enDoPvTAxFSd\"/obsrv_password\ \"$(jq -r '.obsrv_password' $PASSWORD_FILE)\"/g" ../global-values.yaml
sed -i "" "s/superset_admin_password\ \"admin123\"/superset_admin_password\ \"$(jq -r '.superset_admin_password' $PASSWORD_FILE)\"/g" ../global-values.yaml
sed -i "" "s/encryption-key\ \"strong_encryption_key_to_encrypt\"/encryption-key\ \"$(jq -r '.encryption_key' $PASSWORD_FILE)\"/g" ../global-values.yaml