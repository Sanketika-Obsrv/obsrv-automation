global:
  ssl_enabled: &ssl_enabled true
  cloud_storage_provider: &cloud_storage_provider "aws"
  cloud_store_provider: &cloud_store_provider "s3"
  cloud_storage_region: &cloud_storage_region "${cloud_storage_region}"

  dataset_api_container: "${dataset_api_container}"
  config_api_container: "${config_api_container}"
  postgresql_backup_cloud_bucket: &backups_bucket "${postgresql_backup_cloud_bucket}"
  velero_backup_cloud_bucket: &velero_backup_cloud_bucket "${velero_backup_cloud_bucket}"
  cloud_storage_bucket: &cloud_storage_bucket "${cloud_storage_bucket}"
  hudi_metadata_bucket: &hudi_metadata_bucket "s3a://${hudi_metadata_bucket}/hudi"

  cloud_storage_config: |+
    '{"identity":"","credential":"","region":"${cloud_storage_region}"}'

  spark_cloud_bucket: ""
  storage_class_name: &storage_class_name "gp3"
  spark_service_account_arn: &spark_service_account_arn "${spark_sa_annotation}"
  checkpoint_bucket: &checkpoint_bucket "s3://${checkpoint_bucket}"
  deep_store_type: &deep_store_type "s3"
  s3_access_key: &s3-access-key "<fill-value>"
  s3_secret_key: &s3-secret-access-key "<fill-value>"
  s3_endpoint_url: &s3-endpoint-url ""
  kong_annotations: &kong_annotations
    service.beta.kubernetes.io/aws-load-balancer-type: nlb
    service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
    service.beta.kubernetes.io/aws-load-balancer-eip-allocations: "${elastic_ip_allocation_id}"
    service.beta.kubernetes.io/aws-load-balancer-subnets: "${load_balancer_subnet}"

service_accounts:
  enabled: &create_sa true
  secor: &secor_sa_annotation
    eks.amazonaws.com/role-arn: "${secor_sa_annotation}"
  dataset_api: &dataset_api_sa_annotation
    eks.amazonaws.com/role-arn: "${dataset_api_sa_annotation}"
  config_api: &config_api_sa_annotation
    eks.amazonaws.com/role-arn: "${config_api_sa_annotation}"
  druid_raw: &druid_raw_sa_annotation
    eks.amazonaws.com/role-arn: "${druid_raw_sa_annotation}"
  flink: &flink_sa_annotation
    eks.amazonaws.com/role-arn: "${flink_sa_annotation}"
  postgresql_backup: &postgresql_backup_sa_annotation
    eks.amazonaws.com/role-arn: "${postgresql_backup_sa_annotation}"
  s3_exporter: &s3_exporter_sa_annotation
    eks.amazonaws.com/role-arn: "${s3_exporter_sa_annotation}"
  spark: &spark_sa_annotation
    eks.amazonaws.com/role-arn: "${spark_sa_annotation}"
  velero: &velero_sa_annotation
    eks.amazonaws.com/role-arn: "${velero_sa_annotation}"

s3-exporter-service-account: &s3-exporter-service-account
  s3_region: *cloud_storage_region
  serviceAccount:
    create: *create_sa
    name: s3-exporter-sa
    annotations:
      <<: *s3_exporter_sa_annotation

velero-backup: &velero-backup
  serviceAccount:
    server:
      create: *create_sa
      name: velero-backup-sa
      annotations:
        <<: *velero_sa_annotation 
      labels:
  credentials:
    useSecret: false
  configuration:
    backupStorageLocation:
    - name:
      provider: *cloud_storage_provider
      bucket: *velero_backup_cloud_bucket
      config:
        region: *cloud_storage_region
    volumeSnapshotLocation:
      - name:
        provider: *cloud_storage_provider
        config:
          region: *cloud_storage_region
  initContainers:
    - name: velero-plugin-for-aws
      image: velero/velero-plugin-for-aws
      volumeMounts:
        - name: plugins
          mountPath: /target

spark:
  serviceAccount:
    create: *create_sa
    name: spark-sa
    annotations:
      <<: *spark_sa_annotation
  persistence:
    masterTmp:
      storageClassName: *storage_class_name
    workerTmp:
      storageClassName: *storage_class_name
    masterMetadata:
      storageClassName: *storage_class_name
    workerMetadata:
      storageClassName: *storage_class_name
  cloud_provider: *cloud_storage_provider

masterdata-indexer-cron:
  serviceAccount:
    name: spark-sa
    annotations:
      <<: *spark_sa_annotation
  serviceAccountRoleArn: *spark_service_account_arn  
  dataproductsJar: "<fill-value>"

dataset-api-service-account: &dataset-api-service-account
  serviceAccount:
    create: *create_sa
    name: dataset-api-sa
    annotations:  
     <<: *dataset_api_sa_annotation


velero:
  <<: *velero-backup

s3-exporter:
  <<: *s3-exporter-service-account

dataset-api:
  <<: *dataset-api-service-account

secor-service-account: &secor-service-account
  serviceAccount:
    create: *create_sa
    name: secor-sa
    annotations:
      <<: *secor_sa_annotation


secor:
  cloud_store_provider: *cloud_store_provider
  s3_bucket_name: *backups_bucket
  s3_region: *cloud_storage_region
  storageClass: *storage_class_name
  <<: *secor-service-account

kong:
  proxy:
    annotations:
      <<: *kong_annotations
    type: LoadBalancer

flink-service-account: &flink-service-account
  serviceAccount:
    create: *create_sa
    name: flink-sa
    annotations:
      <<: *flink_sa_annotation

flink:
  <<: *flink-service-account
  checkpoint_store_type: *cloud_store_provider
  checkpointing:
    enabled: true
    statebackend: *checkpoint_bucket

postgres-backup-service-account: &postgres-backup-service-account
  serviceAccount:
    create: *create_sa
    name: postgresql-backup-sa
    annotations:
      <<: *postgresql_backup_sa_annotation

postgresql-backup:
  <<: *postgres-backup-service-account

druid-raw-service-account: &druid-raw-service-account
  serviceAccount:
    create: *create_sa
    name: druid-raw-sa
    annotations:
      <<: *druid_raw_sa_annotation

druid-raw-cluster:
  druid_deepstorage_type: *deep_store_type
  druid_indexer_logs_type: *deep_store_type
  storageClass: *storage_class_name
  s3_bucket: *cloud_storage_bucket
  s3_access_key: ""
  s3_secret_key: ""
  <<: *druid-raw-service-account

lakehouse-connector:
  hadoop_core_site:
      fs.s3a.imp: org.apache.hadoop.fs.s3a.S3AFileSystem
      fs.s3a.access.key: *s3-access-key
      fs.s3a.secret.key: *s3-secret-access-key
  serviceAccount:
    create: false
    name: flink-sa
  checkpointing:
    enabled: true
    statebackend: *hudi_metadata_bucket
    annotations:
      <<: *flink_sa_annotation

trino:
  additionalCatalogs:
    lakehouse: |-
      connector.name=hudi
      hive.metastore.uri=thrift://hudi-hms.hms.svc.cluster.local:9083
      hive.s3.aws-access-key=<fill-value>
      hive.s3.aws-secret-key=<fill-value>
      hive.s3.ssl.enabled=false

hms:
  envVars:
    WAREHOUSE_DIR: *hudi_metadata_bucket


  hadoop_core_site:
    fs.s3a.access.key:  *s3-access-key
    fs.s3a.secret.key:  *s3-secret-access-key
    # fs.s3a.endpoint: *s3-endpoint-url
    # fs.s3a.path.style.access: false
    # fs.s3a.connection.ssl.enabled: true

letsencrypt-ssl:
  enabled: *ssl_enabled

keycloak:
  ingress:
    tls: *ssl_enabled
  tls:
    enabled: *ssl_enabled  
