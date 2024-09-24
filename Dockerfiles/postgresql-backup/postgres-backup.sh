#!/bin/bash
set -euo pipefail
backup_dir="/var/postgres/backups"
backup_date=$(date +%y-%m-%dT%T)
mkdir -p $backup_dir/$backup_date

# Dump all
echo "Backup up all databases into $backup_dir/fulldb-$backup_date.sql"
PGPASSWORD=${PGPASSWORD} pg_dumpall -U ${PG_USER} -h ${PG_HOST} > $backup_dir/fulldb-$backup_date.sql
bzip2 $backup_dir/fulldb-$backup_date.sql

if [ "$CLOUD_SERVICE" == "s3" ]; then
    aws s3 cp $backup_dir/fulldb-$backup_date.sql.bz2 s3://${S3_BACKUP_BUCKET}/postgresql/fulldb-$backup_date.sql.bz2
elif [ "$CLOUD_SERVICE" == "gcs" ]; then
    /google-cloud-sdk/bin/gsutil cp $backup_dir/fulldb-$backup_date.sql.bz2 gs://${GS_BACKUP_BUCKET}/postgresql/fulldb-$backup_date.sql.bz2
elif [ "$CLOUD_SERVICE" == "azure" ]; then
    az storage blob upload --account-name ${AZURE_STORAGE_ACCOUNT} \
                          --account-key ${AZURE_KEY} \
                          --container-name ${AZURE_CONTAINER}/postgresql \
                          --name fulldb-$backup_date.sql.bz2 \
                          --type block \
                          --file "$backup_dir/fulldb-$backup_date.sql.bz2" 
else
    echo "No cloud service specified"
fi


