#!/bin/bash

mkdir -p /opt/bitnami/spark/spark-metadata/spark-events /opt/bitnami/spark/spark-metadata/livy /opt/bitnami/spark/spark-metadata/spark-log

# Execute the python
# nohup python /data/connectors-init/connector.py >> /tmp/connectors/connector.log 2>&1 &

# spark.hadoop.fs.s3a.assumed.role.arn arn:aws:iam::725876873105:role/spark-sa
# spark.hadoop.fs.s3a.aws.credentials.provider org.apache.hadoop.fs.s3a.auth.AssumedRoleCredentialProvider
# spark.hadoop.fs.s3a.assumed.role.credentials.provider com.amazonaws.auth.InstanceProfileCredentialsProvider

# Disable the defaults as we are using the spark-defaults.conf file as configmap in helm
# sparkDefaults=$(cat << EOF
# spark.master spark://spark-master-svc:7077
# spark.ui.prometheus.enabled true
# spark.executor.processTreeMetrics.enabled true
# spark.history.fs.logDirectory /opt/bitnami/spark/spark-metadata/spark-events
# spark.eventLog.enabled true
# spark.eventLog.dir /opt/bitnami/spark/spark-metadata/spark-events
# EOF
# )

# echo "$sparkDefaults" >> /opt/bitnami/spark/conf/spark-defaults.conf
