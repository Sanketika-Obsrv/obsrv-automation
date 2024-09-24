#!/bin/bash
set -euo pipefail
touch /REDIS_RDB_FILE_PATH/dump.rdb
if [[ $REDIS_REPLICATION_MODE == "master" ]]
then
  backup_date=$(date +%y-%m-%dT%T)
  echo "Backing up dump.rdb into $CLOUD_SERVICE as dump-$backup_date.rdb"
  /usr/bin/cp REDIS_RDB_FILE_PATH/dump.rdb REDIS_RDB_FILE_PATH/dump-$backup_date.rdb
  /usr/bin/bzip2 -f  REDIS_RDB_FILE_PATH/dump-$backup_date.rdb
  if [ "$CLOUD_SERVICE" == "s3" ]; then
    /usr/local/bin/aws s3 cp REDIS_RDB_FILE_PATH/dump-$backup_date.rdb.bz2 s3://S3_BACKUP_BUCKET/BACKUP_PREFIX/dump-$backup_date.rdb.bz2
  elif [ "$CLOUD_SERVICE" == "gcs" ]; then
    /google-cloud-sdk/bin/gsutil cp REDIS_RDB_FILE_PATH/dump-$backup_date.rdb.bz2 gs://GCS_BACKUP_BUCKET/BACKUP_PREFIX/dump-$backup_date.rdb.bz2
  elif [ "$CLOUD_SERVICE" == "azure" ]; then
    az storage blob upload --account-name AZURE_STORAGE_ACCOUNT_NAME --container-name AZURE_BACKUP_BUCKET/BACKUP_PREFIX --name dump-$backup_date.rdb.bz2 --file REDIS_RDB_FILE_PATH/dump-$backup_date.rdb.bz2 --account-key AZURE_STORAGE_ACCOUNT_KEY
  fi
  /usr/bin/rm -rf REDIS_RDB_FILE_PATH/dump-$backup_date.rdb.bz2
fi