#!/bin/bash
if [[ "$REDIS_BACKUP_CRON_SCHEDULE" != "" && "$CLOUD_SERVICE" != "" && ("$S3_BACKUP_BUCKET" != "" || "$GCS_BACKUP_BUCKET" != "" || "$AZURE_STORAGE_ACCOUNT_NAME" != "") && "$REDIS_RDB_FILE_PATH" != "" ]]; then
  echo "Setting redis backup as a cron job"
  echo "REDIS_BACKUP_CRON_SCHEDULE: ${REDIS_BACKUP_CRON_SCHEDULE}"
  echo "CLOUD_SERVICE: $CLOUD_SERVICE"
  echo "S3_BACKUP_BUCKET: $S3_BACKUP_BUCKET"
  echo "BACKUP_PREFIX: $BACKUP_PREFIX"
  echo "GCS_BACKUP_BUCKET: $GCS_BACKUP_BUCKET"
  echo "AZURE_STORAGE_ACCOUNT_NAME: $AZURE_STORAGE_ACCOUNT_NAME"
  echo "REDIS_RDB_FILE_PATH: $REDIS_RDB_FILE_PATH"
  echo "AZURE_STORAGE_ACCOUNT_KEY: $AZURE_STORAGE_ACCOUNT_KEY"
  echo "AZURE_BACKUP_BUCKET: $AZURE_BACKUP_BUCKET"

  sed -i "s/REDIS_BACKUP_CRON_SCHEDULE/$REDIS_BACKUP_CRON_SCHEDULE/g" /load-cron.cron
  sed -i "s/REPLACE_WITH_REPLICATION_TYPE/$REDIS_REPLICATION_MODE/g" /load-cron.cron

  if [ "$CLOUD_SERVICE" == "s3" ]; then
    sed -i "s/S3_BACKUP_BUCKET/$S3_BACKUP_BUCKET/g" redis-backup.sh
  elif [ "$CLOUD_SERVICE" == "gcs" ]; then
    sed -i "s/GCS_BACKUP_BUCKET/$GCS_BACKUP_BUCKET/g" redis-backup.sh
  elif [ "$CLOUD_SERVICE" == "azure" ]; then
    sed -i "s/AZURE_STORAGE_ACCOUNT_NAME/$AZURE_STORAGE_ACCOUNT_NAME/g" redis-backup.sh
    sed -i 's/AZURE_STORAGE_ACCOUNT_KEY/$AZURE_STORAGE_ACCOUNT_KEY/g' redis-backup.sh
    sed -i 's/AZURE_BACKUP_BUCKET/$AZURE_BACKUP_BUCKET/g' redis-backup.sh
  fi

  sed -i "s#REDIS_RDB_FILE_PATH#$REDIS_RDB_FILE_PATH#g" redis-backup.sh
  sed -i "s#BACKUP_PREFIX#$BACKUP_PREFIX#g" redis-backup.sh



  printenv | sed 's/^\(.*\)$/export "\1"/g' > /etc/profile.d/envs.sh && chmod +x /etc/profile.d/envs.sh

  # Add a newline character at the end of the crontab file
  echo >> /load-cron.cron

  crontab -u root /load-cron.cron
fi