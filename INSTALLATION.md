# Obsrv
## Introduction
Obsrv is a platform that enables you to manage your data workflows from ingestion, all the way to reporting. With a high level of abstraction, anyone can create datasets, set up connectors to various data sources, define data manipulations and export the aggregations via multiple data visualization tools, all with minimal technical debt/knowledge. Obsrv is built under the hood using the latest open source tools that can be swapped, plugged in or out depending on use cases. Obsrv comes with a set of microservices, APIs, and some utility SDKs. Obsrv also has a built-in open data cataloging and publishing capability.
## Obsrv Components
* [Obsrv Automation](https://github.com/Sunbird-Obsrv/obsrv-automation): Components related to deployment of various obsrv components
* [Obsrv Streaming Tasks](https://github.com/Sunbird-Obsrv/obsrv-core): Components related to processing data
* [Obsrv API service](https://github.com/Sunbird-Obsrv/obsrv-api-service): Components related to API services within Obsrv
* [Obsrv Web Console](https://github.com/Sunbird-Obsrv/obsrv-web-console): Components related to Obsrv Web Console
## Keywords
- **Dataset**:
In Obsrv, a Dataset is a logical entity that encapsulates a dataset, i.e. a structured collection of data. Typically, this will be your data that is created/ingested frequently. A well structured data will have metadata properties like type of event, producer of event, timestamps related to event creation, modification, ingestion. In Obsrv, a Dataset has properties like event schema, status, creation and modification metadata, configuration properties like validation config, deduplication config, extraction config, denormalization config.  
- **Master Dataset**:
A Master Dataset is conceptually similar to a Dataset in that it is a collection of structured data. However, a Master Dataset is used to store data that can enrich a Dataset. A Master Dataset doesn't generally get frequently generated or updated but acts like a cache repository for denorm data to be used by a Dataset. You will need to specify the primary key for a Master dataset that will act as the lookup.
- **Datasource**:
A Datasource is a representation of a Dataset that gets ingested in the analytical data store, i.e. Druid. It will contain configuration  related to indexing it in Druid like ingestion spec, archival policy, etc.
## Open Source Tools used in Obsrv
* [Postgres](https://www.postgresql.org/about/)
* [Kafka](https://kafka.apache.org/documentation/#gettingStarted)
* [Secor](https://github.com/pinterest/secor)
* [Flink](https://flink.apache.org/)
* [Redis](https://redis.io/docs/about/)
* [Druid](https://druid.apache.org/)
* Monitoring([Prometheus](https://prometheus.io/) and [Grafana](https://grafana.com/))
* [Superset](https://superset.apache.org/)
* [Velero](https://velero.io/)
## Installation
To install Obsrv, you will need to clone the [Obsrv Automation](https://github.com/Sunbird-Obsrv/obsrv-automation) repository. It provides support for installation across major cloud providers. Please check [here](#configurations) for all the various configurations across all components.

You will require `terragrunt` to install Obsrv components. Please see [Install Terragrunt](https://terragrunt.gruntwork.io/docs/getting-started/install/) for installation help.  
**AWS**  
Prerequisites:
- You will need a `key-secret` pair to access AWS. Learn how to create or manage these at [Managing access keys for IAM users](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html). Please export these variables in terminal session.
    ```
    export AWS_ACCESS_KEY_ID=mykey
    export AWS_SECRET_ACCESS_KEY=mysecret
    ```    
- You will require an S3 bucket to store tf-state. Learn how to create or manage these at [Create an Amazon S3 bucket](https://docs.aws.amazon.com/transfer/latest/userguide/requirements-S3.html). Please export this variable at
    ```
    export AWS_TERRAFORM_BACKEND_BUCKET_NAME=mybucket
    export AWS_TERRAFORM_BACKEND_BUCKET_REGION=myregion
    ```

#### Steps:
* Execute the below steps in the same terminal session:
    ```
    export KUBE_CONFIG_PATH=~/.kube/config
    cd terraform/aws
    terragrunt init
    terragrunt plan
    terragrunt apply -target=module.eks
    terragrunt apply -target=module.get_kubeconfig -auto-approve
    terragrunt apply
    ```
The installer will ask for user inputs twice:
 - Before creating the EKS cluster
 - Before creating rest of the components

#### Tip:
Add `-auto-approve` to the above `terragrunt` command to install without providing user inputs as shown below
```
terragrunt apply -target=module.eks -auto-approve && terragrunt apply -target=module.get_kubeconfig -auto-approve && terragrunt apply -auto-approve
```

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
### Steps:
* Execute the below commands in the same terminal session: 
    ```
    cd terraform/azure
    terragrunt init
    terragrunt plan
    terragrunt apply
    ```
**GCP**
### Prerequisites:
* Setup the gcoud CLI. Please see [Installing Google Cloud SDK](https://cloud.google.com/sdk/docs/install) for reference.
* Initialize and Authenticate the gcloud CLI. Please see [Initializing Cloud SDK](https://cloud.google.com/sdk/docs/initializing) for reference.
    ```
    gcloud init
    gcloud auth login
    ``` 
*  Install additional dependencies to authenticate with GKE. Please see [Installing the gke-gcloud-auth-plugin](https://cloud.google.com/kubernetes-engine/docs/how-to/cluster-access-for-kubectl) for reference.
    ```
    gcloud components install gke-gcloud-auth-plugin
    ```
*  Create a project and export it as variable. Please see [Creating and Managing Projects](https://cloud.google.com/resource-manager/docs/creating-managing-projects) for reference.
    ```
    export GOOGLE_CLOUD_PROJECT=myproject
    export GOOGLE_TERRAFORM_BACKEND_BUCKET=mybucket
    ```
* Enable the Kubernets Engine API for the created project. Please see [Enabling the Kubernetes Engine API](https://cloud.google.com/kubernetes-engine/docs/how-to/creating-a-zonal-cluster#enable-api) for reference.
### Steps:
* Execute the below steps in the same terminal session:
    ```
    cd terraform/gcp
    terragrunt init
    terragrunt plan
    terragrunt apply
    ```
## Cluster Access
To view cluster metrics and access the Obsrv services, you can either port forward or use the Load Balancer IP if available.

To port forward any Obsrv service, try the following command: 
```
kubectl port-forward <obsrv-service-name> -n <service namespace> <local-port>:<remote-port>
```
## Obsrv Use Cases
We will explore a few use cases of Dataset Creation, Data Ingestion and Data Querying below. We will be explaining how to achieve this via Obsrv API service.  
- port forward the API service using 
    ```
    kubectl port-forward <api-service-name> -n <obsrv-api-namespace> 3000:3000
    ```
- The API service is now accessible at localhost:3000.
- Port forward Druid service within the cluster, use the command: 
    ```
    kubectl port-forward <your-druid-service> -n <druid-namespace> 8888:8888
    ```
## Create a Dataset
- Dataset Configurations:
    - **extraction_config**: It defines how the data is extracted from the source. `is_batch_event` determines whether the extraction is done in batches or not. The `extraction_key` specifies the key used for extraction.
    - **validation_config**: It defines the validation rules applied to the dataset. It includes parameters like whether validation is enabled and what the validation mode is.
    - **dedup_config**: It defines how to handle duplicate records in the dataset. It includes parameters like whether to drop duplicates, the key used for deduplication, and the deduplication period in seconds.
    - **data_schema**: JSON schema of the data in the dataset.
    - **denorm_config**: It defines which field to perform the denorm on, where the cache is located and what the new field name should be.
    - **router_config**: It defines the Kafka topic to which the dataset is published.
    - **dataset_config**: In case it's a Master Dataset, this configuration defines where to store it, what index to use, which is the primary key, which is the timestamp key, etc.
- Creating a master dataset  
  - **End Point**: `/obsrv/v1/datasets`  
  - **Method**: `POST`  
  - **Request Body:**
    ```json
    {"id":"sb-telemetry-user","dataset_id":"sb-telemetry-user","type":"master-dataset","name":"sb-telemetry-user","validation_config":{"validate":true,"mode":"Strict"},"extraction_config":{"is_batch_event":false,"extraction_key":"","dedup_config":{"drop_duplicates":false,"dedup_key":"id","dedup_period":1036800}},"dedup_config":{"drop_duplicates":true,"dedup_key":"id","dedup_period":1036800},"data_schema":{"$schema":"https://json-schema.org/draft/2020-12/schema","type":"object","properties":{"subject":{"type":"array","items":{"type":"string"}},"channel":{"type":"string"},"language":{"type":"array","items":{"type":"string"}},"id":{"type":"string"},"firstName":{"type":"string"},"lastName":{"type":"string"},"mobile":{"type":"string"},"email":{"type":"string"},"state":{"type":"string"},"district":{"type":"string"}}},"denorm_config":{"redis_db_host":"obsrv-redis-master.redis.svc.cluster.local","redis_db_port":6379,"denorm_fields":[]},"router_config":{"topic":"user-master"},"dataset_config":{"data_key":"id","timestamp_key":"","exclude_fields":[],"entry_topic":"dev.masterdata.ingest","redis_db_host":"obsrv-redis-master.redis.svc.cluster.local","redis_db_port":6379,"index_data":false,"redis_db":3},"status":"ACTIVE","created_by":"SYSTEM","updated_by":"SYSTEM","published_date":"2023-05-19 05:46:01.854692","tags":[],"data_version":null}
    ```
- Create a dataset with denormalized configurations  
**End Point**: `/obsrv/v1/datasets`  
**Method**: `POST`  
**Request Body:**
    ```json
    {"id":"sb-telemetry","dataset_id":"sb-telemetry","type":"dataset","name":"sb-telemetry","validation_config":{"validate":true,"mode":"Strict","validation_mode":"Strict"},"extraction_config":{"is_batch_event":true,"extraction_key":"events","dedup_config":{"drop_duplicates":true,"dedup_key":"id","dedup_period":1036800},"batch_id":"id"},"dedup_config":{"drop_duplicates":true,"dedup_key":"mid","dedup_period":1036800},"data_schema":{"$schema":"https://json-schema.org/draft/2020-12/schema","type":"object","properties":{"eid":{"type":"string"},"ets":{"type":"integer","format":"date-time"},"ver":{"type":"string"},"mid":{"type":"string","oneof":[{"type":"integer"},{"type":"string"}]},"actor":{"type":"object","properties":{"id":{"type":"string"},"type":{"type":"string"}}},"context":{"type":"object","properties":{"channel":{"type":"string"},"pdata":{"type":"object","properties":{"id":{"type":"string"},"ver":{"type":"string"},"pid":{"type":"string"}}},"env":{"type":"string"},"sid":{"type":"string","format":"uuid"},"did":{"type":"string"},"rollup":{"type":"object","properties":{"l1":{"type":"string"}}},"uid":{"type":"string"},"cdata":{"type":"array","additionalProperties":true}}},"object":{"type":"object","properties":{"id":{"type":"string"},"type":{"type":"string"},"ver":{"type":"string"}}},"tags":{"type":"array","items":{"type":"string"}},"edata":{"type":"object","properties":{"type":{"type":"string"},"pageid":{"type":"string"},"subtype":{"type":"string"},"uri":{"type":"string","format":"uri"},"visits":{"type":"array","additionalProperties":true},"level":{"type":"string"},"message":{"type":"string"},"params":{"type":"array","additionalProperties":true},"size":{"type":"integer"},"query":{"type":"string"},"filters":{"type":"object","properties":{"isTenant":{"type":"boolean"},"framework":{"type":"object"},"mimeType":{"type":"object"},"resourceType":{"type":"object"},"subject":{"type":"array","additionalProperties":true},"se_boards":{"type":"array","additionalProperties":true},"se_mediums":{"type":"array","additionalProperties":true},"se_gradeLevels":{"type":"array","additionalProperties":true},"primaryCategory":{"type":"array","additionalProperties":true},"objectType":{"type":"array","additionalProperties":true},"channel":{"type":"array","additionalProperties":true},"contentType":{"type":"array","additionalProperties":true},"visibility":{"type":"array","additionalProperties":true},"batches.status":{"type":"array","items":{"type":"integer"}},"batches.enrollmentType":{"type":"string"},"status":{"type":"array","additionalProperties":true},"migratedVersion":{"type":"integer"},"identifiers":{"type":"array","additionalProperties":true}}},"sort":{"type":"object","properties":{"lastPublishedOn":{"type":"string"}}},"topn":{"type":"array","additionalProperties":true},"props":{"type":"array","additionalProperties":true},"duration":{"type":"integer"},"state":{"type":"string"},"prevstate":{"type":"string"}}},"syncts":{"type":"integer","format":"date-time"},"@timestamp":{"type":"string","format":"date-time"},"flags":{"type":"object","properties":{"ex_processed":{"type":"boolean"}}}},"required":["ets"]},"denorm_config":{"redis_db_host":"obsrv-redis-master.redis.svc.cluster.local","redis_db_port":6379,"denorm_fields":[{"denorm_key":"actor.id","redis_db":3,"denorm_out_field":"user_metadata"}]},"router_config":{"topic":"sb-telemetry"},"dataset_config":{"data_key":"id","timestamp_key":"","exclude_fields":[],"entry_topic":"dev.masterdata.ingest","redis_db_host":"obsrv-redis-master.redis.svc.cluster.local","redis_db_port":6379,"index_data":false,"redis_db":3},"status":"ACTIVE","created_by":"SYSTEM","updated_by":"SYSTEM","created_date":"2023-05-31 12:15:42.845622","updated_date":"2023-05-31 12:15:42.845622","published_date":"2023-05-31 12:15:42.845622","tags":null,"data_version":null}
    ```
## Data Ingestion
- To ingest the data in Druid, you will need to create it's ingestion spec. For reference, please see [Apache Kafka ingestion](https://druid.apache.org/docs/latest/development/extensions-core/kafka-ingestion.html) for detailed instructions and examples.
- Create a Datasource based on the Dataset:   
    **End Point**: `/obsrv/v1/datasources`  
    **Method**: `POST`  
    **Request Body**:
    ```json
    {"id":"sb-telemetry_sb-telemetry","datasource":"sb-telemetry","dataset_id":"sb-telemetry","ingestion_spec":{"type":"kafka","spec":{"dataSchema":{"dataSource":"sb-telemetry","dimensionsSpec":{"dimensions":[{"type":"string","name":"eid"},{"type":"long","name":"ets"},{"type":"string","name":"ver"},{"type":"string","name":"mid"},{"type":"string","name":"actor_id"},{"type":"string","name":"actor_type"},{"type":"string","name":"context_channel"},{"type":"string","name":"context_pdata_id"},{"type":"string","name":"context_pdata_ver"},{"type":"string","name":"context_pdata_pid"},{"type":"string","name":"context_env"},{"type":"string","name":"context_sid"},{"type":"string","name":"context_did"},{"type":"string","name":"context_rollup_l1"},{"type":"string","name":"context_uid"},{"type":"array","name":"context_cdata"},{"type":"string","name":"object_id"},{"type":"string","name":"object_type"},{"type":"string","name":"object_ver"},{"type":"array","name":"tags"},{"type":"string","name":"edata_type"},{"type":"string","name":"edata_pageid"},{"type":"string","name":"edata_subtype"},{"type":"string","name":"edata_uri"},{"type":"array","name":"edata_visits"},{"type":"string","name":"edata_level"},{"type":"string","name":"edata_message"},{"type":"array","name":"edata_params"},{"type":"string","name":"edata_query"},{"type":"boolean","name":"edata_filters_isTenant"},{"type":"array","name":"edata_filters_subject"},{"type":"array","name":"edata_filters_se_boards"},{"type":"array","name":"edata_filters_se_mediums"},{"type":"array","name":"edata_filters_se_gradeLevels"},{"type":"array","name":"edata_filters_primaryCategory"},{"type":"array","name":"edata_filters_objectType"},{"type":"array","name":"edata_filters_channel"},{"type":"array","name":"edata_filters_contentType"},{"type":"array","name":"edata_filters_visibility"},{"type":"array","name":"edata_filters_batches_status"},{"type":"string","name":"edata_filters_batches_enrollmentType"},{"type":"array","name":"edata_filters_status"},{"type":"array","name":"edata_filters_identifiers"},{"name":"edata_filters_batches"},{"type":"string","name":"edata_sort_lastPublishedOn"},{"type":"array","name":"edata_topn"},{"type":"array","name":"edata_props"},{"type":"string","name":"edata_state"},{"type":"string","name":"edata_prevstate"},{"type":"string","name":"@timestamp"},{"type":"boolean","name":"flags_ex_processed"},{"type":"json","name":"user_metadata"}]},"timestampSpec":{"column":"syncts","format":"auto"},"metricsSpec":[{"type":"doubleSum","name":"edata_size","fieldName":"edata_size"},{"type":"doubleSum","name":"edata_filters_migratedVersion","fieldName":"edata_filters_migratedVersion"},{"type":"doubleSum","name":"edata_duration","fieldName":"edata_duration"}],"granularitySpec":{"type":"uniform","segmentGranularity":"DAY","rollup":false}},"tuningConfig":{"type":"kafka","maxBytesInMemory":134217728,"maxRowsPerSegment":500000,"logParseExceptions":true},"ioConfig":{"type":"kafka","topic":"sb-telemetry","consumerProperties":{"bootstrap.servers":"kafka-headless.kafka.svc:9092"},"taskCount":1,"replicas":1,"taskDuration":"PT1H","useEarliestOffset":true,"completionTimeout":"PT1H","inputFormat":{"type":"json","flattenSpec":{"useFieldDiscovery":true,"fields":[{"type":"path","expr":"$.eid","name":"eid"},{"type":"path","expr":"$.ets","name":"ets"},{"type":"path","expr":"$.ver","name":"ver"},{"type":"path","expr":"$.mid","name":"mid"},{"type":"path","expr":"$.actor.id","name":"actor_id"},{"type":"path","expr":"$.actor.type","name":"actor_type"},{"type":"path","expr":"$.context.channel","name":"context_channel"},{"type":"path","expr":"$.context.pdata.id","name":"context_pdata_id"},{"type":"path","expr":"$.context.pdata.ver","name":"context_pdata_ver"},{"type":"path","expr":"$.context.pdata.pid","name":"context_pdata_pid"},{"type":"path","expr":"$.context.env","name":"context_env"},{"type":"path","expr":"$.context.sid","name":"context_sid"},{"type":"path","expr":"$.context.did","name":"context_did"},{"type":"path","expr":"$.context.rollup.l1","name":"context_rollup_l1"},{"type":"path","expr":"$.context.uid","name":"context_uid"},{"type":"path","expr":"$.context.cdata[*]","name":"context_cdata"},{"type":"path","expr":"$.object.id","name":"object_id"},{"type":"path","expr":"$.object.type","name":"object_type"},{"type":"path","expr":"$.object.ver","name":"object_ver"},{"type":"path","expr":"$.tags[*]","name":"tags"},{"type":"path","expr":"$.edata.type","name":"edata_type"},{"type":"path","expr":"$.edata.pageid","name":"edata_pageid"},{"type":"path","expr":"$.edata.subtype","name":"edata_subtype"},{"type":"path","expr":"$.edata.uri","name":"edata_uri"},{"type":"path","expr":"$.edata.visits[*]","name":"edata_visits"},{"type":"path","expr":"$.edata.level","name":"edata_level"},{"type":"path","expr":"$.edata.message","name":"edata_message"},{"type":"path","expr":"$.edata.params[*]","name":"edata_params"},{"type":"path","expr":"$.edata.query","name":"edata_query"},{"type":"path","expr":"$.edata.filters.isTenant","name":"edata_filters_isTenant"},{"type":"path","expr":"$.edata.filters.subject[*]","name":"edata_filters_subject"},{"type":"path","expr":"$.edata.filters.se_boards[*]","name":"edata_filters_se_boards"},{"type":"path","expr":"$.edata.filters.se_mediums[*]","name":"edata_filters_se_mediums"},{"type":"path","expr":"$.edata.filters.se_gradeLevels[*]","name":"edata_filters_se_gradeLevels"},{"type":"path","expr":"$.edata.filters.primaryCategory[*]","name":"edata_filters_primaryCategory"},{"type":"path","expr":"$.edata.filters.objectType[*]","name":"edata_filters_objectType"},{"type":"path","expr":"$.edata.filters.channel[*]","name":"edata_filters_channel"},{"type":"path","expr":"$.edata.filters.contentType[*]","name":"edata_filters_contentType"},{"type":"path","expr":"$.edata.filters.visibility[*]","name":"edata_filters_visibility"},{"type":"path","expr":"$.edata.filters.batches.status[*]","name":"edata_filters_batches_status"},{"type":"path","expr":"$.edata.filters.batches.enrollmentType","name":"edata_filters_batches_enrollmentType"},{"type":"path","expr":"$.edata.filters.status[*]","name":"edata_filters_status"},{"type":"path","expr":"$.edata.filters.identifiers[*]","name":"edata_filters_identifiers"},{"type":"path","expr":"$.edata.filters.batches","name":"edata_filters_batches"},{"type":"path","expr":"$.edata.sort.lastPublishedOn","name":"edata_sort_lastPublishedOn"},{"type":"path","expr":"$.edata.topn[*]","name":"edata_topn"},{"type":"path","expr":"$.edata.props[*]","name":"edata_props"},{"type":"path","expr":"$.edata.state","name":"edata_state"},{"type":"path","expr":"$.edata.prevstate","name":"edata_prevstate"},{"type":"path","expr":"$.obsrv_meta.syncts","name":"syncts"},{"type":"path","expr":"$.@timestamp","name":"@timestamp"},{"type":"path","expr":"$.flags.ex_processed","name":"flags_ex_processed"},{"type":"path","expr":"$.user_metadata","name":"user_metadata"},{"type":"path","expr":"$.edata.size","name":"edata_size"},{"type":"path","expr":"$.edata.filters.migratedVersion","name":"edata_filters_migratedVersion"},{"type":"path","expr":"$.edata.duration","name":"edata_duration"}]}},"appendToExisting":false}}},"datasource_ref":"sb-telemetry","retention_period":{"enabled":"false"},"archival_policy":{"enabled":"false"},"purge_policy":{"enabled":"false"},"backup_config":{"enabled":"false"},"status":"ACTIVE","created_by":"SYSTEM","updated_by":"SYSTEM","published_date":"2023-05-31 12:15:42.881752"}
    ```
- Submit the ingestion task to Druid  
  **End Point**: `/druid/indexer/v1/supervisor`  
  **Method**: `POST`  
  **Request Body**: `<ingestion spec from datasource created in above step>`   
- Ingest events using Obsrv API service:
    - Push events for Master Dataset:  
        **End Point**: `/obsrv/v1/data/{datasetId}`  
        **Method**: `POST`  
        **Request Body**:
        ```json
        {"data":{"event":{"subject":["Mathematics"],"channel":"Future Assurance Consultant","language":["English"],"id":"user-00","firstName":"Karan","lastName":"Panicker","mobile":"+91-602-8988588","email":"Karan_Panicker@obsrv.ai","state":"Gujarat","district":"Bedfordshire"}}}
        ```
    - Push events for Dataset:  
        **End Point**:`/obsrv/v1/data/{datasetId}`  
        **Method**:`POST`  
        **Request Body**:
        ```json
        {"data":{"id":"dedup-id-1","events":[{"eid":"IMPRESSION","ets":1672657002221,"ver":"3.0","mid":124435,"actor":{"id":"user-00","type":"User"},"context":{"channel":"01268904781886259221","pdata":{"id":"staging.diksha.portal","ver":"5.1.0","pid":"sunbird-portal"},"env":"public","sid":"23850c90-8a8c-11ed-95d0-276800e1048c","did":"0c45959486f579c24854d40a225d6161","cdata":[],"rollup":{"l1":"01268904781886259221"},"uid":"anonymous"},"object":{},"tags":["01268904781886259221"],"edata":{"type":"view","pageid":"login","subtype":"pageexit","uri":"https://staging.sunbirded.org/auth/realms/sunbird/protocol/openid-connect/auth?client_id=portal&state=254efd70-6b89-4f7d-868b-5c957f54174e&redirect_uri=https%253A%252F%252Fstaging.sunbirded.org%252Fresources%253Fboard%253DState%252520(Andhra%252520Pradesh)%2526medium%253DEnglish%2526gradeLevel%253DClass%2525201%2526%2526id%253Dap_k-12_1%2526selectedTab%253Dhome%2526auth_callback%253D1&scope=openid&response_type=code&version=4","visits":[]},"syncts":1672657005814,"@timestamp":"2023-01-02T10:56:45.814Z","flags":{"ex_processed":true}}]}}
        ```
- Ingest events using Obsrv Kafka Connector:
    * If your data is present in a Kafka topic, you can create a source configuration for the dataset in Obsrv.
    * Create a dataset source configuration for the existing dataset in Obsrv. The Kafka connector facilitates event extraction from the Kafka topic and smooth transfer to the pipeline's entry topic.
    * By creating the source configuration, you can seamlessly integrate the Kafka topic data into Obsrv's pipeline for efficient processing and analysis.  
    **End Point**: `/obsrv/v1/dataset/source/config`  
    **Method**:`POST`  
    **Request Body**:
        ```json
        {"dataset_id":"sb-telemetry","connector_type":"kafka","connector_config":{"type":"kafka","topic":"telemetry.input","kafkaBrokers":"kafka-headless.kafka.svc:9092"},"status":"ACTIVE","published_date":"2023-03-24 12:19:32.091544"}
        ```
## Data Query
- You can query the Dataset via Obsrv API using Druid Native or SQL syntax.  
    - For native query:  
    **End Point**:`/obsrv/v1/query`  
    **Method**:`POST`  
    **Request Body**:
        ```json
        {"context":{"dataSource":"sb-telemetry"},"query":{"queryType":"scan","dataSource":"sb-telemetry","intervals":"2023-03-31/2023-04-01","granularity":"DAY"}}
        ```
    - For SQL query:  
    **End Point**:`/obsrv/v1/sql-query`  
    **Method**:`POST`  
    **Request Body**:
        ```json
        {"context":{"dataSource":"sb-telemetry"},"querySql":"SELECT COUNT(*) FROM \"sb-telemetry\";"}
        ```
For more info on Obsrv API Service refer [here](https://github.com/Sunbird-Obsrv/obsrv-api-service/tree/main/swagger-doc). You can use [Swagger Editor](https://editor.swagger.io/) to view it.
## **Note**
Please note that all the URLs and connection configurations mentioned above are based on the default configurations set up in Terraform variables in Obsrv Automation Repository. Feel free to modify the URLs in the JSON payloads provided according to your specific deployments. Please ensure that you update the URLs with the appropriate values based on your deployment settings. To reference the default configurations for the OBSRV API service and streaming tasks, please refer to the information provided below.
## Configurations
## Obsrv API Service Default configurations
Please note that these configurations can be modified as needed to customize the behavior of the API service.
| Configuration            | Description                                                    | Data Type   | Default Value        |
|--------------------------|----------------------------------------------------------------|-------------|----------------------|
| system_env               | Environment in which the system is running.                     | String      | dev                |
| api_port                 | Port on which the API server should listen for incoming requests.| Number      | 3000                 |
| body_parser_limit        | Maximum size limit for parsing request bodies.                  | String      | 100mb                |
| druid_host               | Hostname or IP address of the Druid server.                     | String url     | `http://druid-raw-routers.druid-raw.svc` or `http://localhost`     |
| druid_port               | Port number on which the Druid server is running.               | Number      | 8888                 |
| postgres_host            | Hostname or IP address of the PostgreSQL database server.       | String      | `postgresql-hl.postgresql.svc` or `localhost`           |
| postgres_port            | Port number on which the PostgreSQL server is running.          | Number      | 5432                 |
| postgres_database        | Name of the PostgreSQL database to connect to.                  | String      | obsrv             |
| postgres_username        | Username to use when connecting to the PostgreSQL database.     | String      | obsrv                |
| postgres_password        | Password to use when connecting to the PostgreSQL database.     | String      | obsrv123            |
| kafka_host               | Hostname or IP address of the Kafka server.                     | String      | `kafka-headless.kafka.svc`  or `localhost`          |
| kafka_port               | Port number on which the Kafka server is running.               | Number      | 9092                 |
| client_id                | Client ID for authentication or identification purposes.        | String      | obsrv-apis           |
| redis_host               | Hostname or IP address of the Redis server.                     | String      | `obsrv-redis-master.redis.svc.cluster.local`   or `localhost`        |
| redis_port               | Port number on which the Redis server is running.               | Number      | 6379                 |
| exclude_datasource_validation | List of datasource names that should be excluded from validation. | Array       | ["system-stats", "masterdata-system-stats"] |
| max_query_threshold      | Maximum threshold value for queries.                            | Number      | 5000                 |
| max_query_limit          | Maximum limit value for queries.                                | Number      | 5000                 |
| max_date_range           | Maximum date range value for queries                            | Number      | 30                   |
## Default Configurations in Obsrv Streaming Tasks:
Please note that these configurations can be modified as needed to customize the behavior of the pipeline.
 * [Common config](#common-configuration)
 * [Dataset Registry config](#dataset-registry)
 * [Extraction Job config](#extractor-job)
 * [Preprocessor Job config](#preprocessor-job)
 * [Denorm Job config](#denormalizer-job)
 * [Router Job config](#router-job)
 * [Kafka Connector Job config](#kafka-connector-job)
 * [Masterdata Processor Job Config](#masterdata-processor-job)
## Common Configuration
| Configuration                          |Description                                                                  |Data Type| Default Value                 |
|--------------------------------------------|-------|---------------------------------------------------------------------|-------------------------------|
| kafka.consumer.broker-servers                      | Kafka broker servers for the consumer | string                                            | `kafka-headless.kafka.svc:9092` or `localhost:9092`                |
| kafka.producer.broker-servers                      | Kafka broker servers for the producer| string                                             | `kafka-headless.kafka.svc:9092` or `localhost:9092`                |
| kafka.producer.max-request-size                    | Maximum request size for the Kafka producer in bytes  | number                            | 1572864                       |
| kafka.producer.batch.size                          | Batch size for the Kafka producer in bytes  | number                                      | 98304                         |
| kafka.producer.linger.ms                           | Linger time in milliseconds for the Kafka producer      | number                          | 10                            |
| kafka.producer.compression                         | Compression type for the Kafka producer    | string                                        | snappy                        |
| kafka.output.system.event.topic                    | Output Kafka topic for system events    | string                                          | dev.system.events           |
| job.env                                            | Environment for the Flink job | string                                                     | dev                         |
| job.enable.distributed.checkpointing               | Flag indicating whether distributed checkpointing is enabled for the job  |boolean        | false                         |
| job.statebackend.base.url                          | Base URL for the state backend      |string    url                                            | s3://checkpoint-obsrv-dev |
| task.checkpointing.compressed                      | Flag indicating whether checkpointing is compressed |boolean                              | true                          |
| task.checkpointing.interval                        | Interval between checkpoints in milliseconds |number                                    | 60000                         |
| task.checkpointing.pause.between.seconds           | Pause between checkpoints in seconds |number                                             | 30000                         |
| task.restart-strategy.attempts                     | Number of restart attempts for the job|number                                            | 3                             |
| task.restart-strategy.delay                        | Delay between restart attempts in milliseconds |number                                   | 30000                         |
| task.parallelism                                   | Parallelism for the Flink job tasks|number                                               | 1                             |
| task.consumer.parallelism                          | Parallelism for the task consumers  |number                                              | 1                             |
| task.downstream.operators.parallelism              | Parallelism for downstream operators |number                                             | 1                             |
| redis.host                                         | Hostname of the Redis server| string                                                       | `obsrv-redis-master.redis.svc.cluster.local`   or `localhost`                      |
| redis.port                                         | Port number of the Redis server| number                                                    | 6379                          |
| redis.connection.timeout                           | Connection timeout for Redis in milliseconds |number                                     | 30000                         |
| redis-meta.host                                    | Hostname of the Redis server for metadata |string                                         | `obsrv-redis-master.redis.svc.cluster.local`   or `localhost`                      |
| redis-meta.port                                    | Port number of the Redis server for metadata   |number                                    | 6379                          |
| postgres.host                                      | Hostname or IP address of the PostgreSQL server  |string                                 | `postgresql-hl.postgresql.svc` or `localhost`                            |
| postgres.port                                      | Port number of the PostgreSQL server |number                                             | 5432                          |
| postgres.maxConnections                            | Maximum number of connections to the PostgreSQL server|number                            | 2                             |
| postgres.user                                      | PostgreSQL username | string                                                             | obsrv                      |
| postgres.password                                  | PostgreSQL password  |string                                                            | obsrv123                      |
| postgres.database                                  | Name of the PostgreSQL database   |string                                                | obsrv                      |
## Dataset Registry
| Configuration         | Description                  |Data type| Default Value   |
|-----------------------|-----------------------------|----------|-----------------|
| postgres.host         | Hostname or IP address       |string| localhost       |
| postgres.port         | Port number                  |number| 5432            |
| postgres.maxConnections | Maximum number of connections |number| 2            |
| postgres.user         | PostgreSQL username         |string | obsrv           |
| postgres.password     | PostgreSQL password          |string| obsrv123        |
| postgres.database     | Database name                |string| obsrv  |
## Extractor Job
| Configuration             | Description                      |Data type| Default Value   |
|---------------------------|----------------------------------|---------|-----------------|
| kafka.input.topic         | Input Kafka topic                |string| dev.ingest |
| kafka.output.raw.topic    | Output Kafka topic for raw data  |string| dev.raw |
| kafka.output.extractor.duplicate.topic | Output Kafka topic for duplicate data in extractor |string| dev.extractor.duplicate |
| kafka.output.failed.topic | Output Kafka topic for failed data |string| dev.failed |
| kafka.output.batch.failed.topic | Output Kafka topic for failed extractor batches |string| dev.extractor.failed |
| kafka.event.max.size      | Maximum size of a Kafka event    |string| "1048576" (1MB) |
| kafka.groupId             | Kafka consumer group ID          |string| dev-extractor-group |
| kafka.producer.max-request-size | Maximum request size for Kafka producer |number| 5242880 |
| task.consumer.parallelism | Parallelism for task consumers   |number| 1               |
| task.downstream.operators.parallelism | Parallelism for downstream operators |number| 1 |
| redis.database.extractor.duplication.store.id | Redis database ID for extractor duplication store |number| 1 |
| redis.database.key.expiry.seconds | Expiry time for Redis keys (in seconds) |number| 3600 |
## Preprocessor Job
| Configuration             | Description                      |Data type| Default Value   |
|---------------------------|----------------------------------|----------|-----------------|
| kafka.input.topic         | Input Kafka topic                |string| dev.raw |
| kafka.output.failed.topic | Output Kafka topic for failed data |string| dev.failed |
| kafka.output.invalid.topic | Output Kafka topic for invalid data |string| dev.invalid |
| kafka.output.unique.topic | Output Kafka topic for unique data |string| dev.unique |
| kafka.output.duplicate.topic | Output Kafka topic for duplicate data |string| dev.duplicate |
| kafka.groupId             | Kafka consumer group ID          |string| dev-pipeline-preprocessor-group |
| task.consumer.parallelism | Parallelism for task consumers   |number| 1               |
| task.downstream.operators.parallelism | Parallelism for downstream operators |number| 1 |
| redis.database.preprocessor.duplication.store.id | Redis database ID for preprocessor duplication store |number| 2 |
| redis.database.key.expiry.seconds | Expiry time for Redis keys (in seconds) |number| 3600 |
## Denormalizer Job
| Configuration                      | Description                                         |Data type| Default Value          |
|------------------------------------|------------------------------------------------------|----|------------------------|
| kafka.input.topic                  | Input Kafka topic                                    |string| dev.unique           |
| kafka.output.denorm.topic          | Output Kafka topic for denormalized data              |string| dev.denorm           |
| kafka.output.denorm.failed.topic   | Output Kafka topic for failed denormalization         |string| dev.denorm.failed    |
| kafka.groupId                      | Kafka consumer group ID                              |string| dev-denormalizer-group |
| task.window.time.in.seconds        | Time duration for window in seconds                   |number| 5                      |
| task.window.count                  | configuration specifies the number of events (elements) that will be included in each window. It determines the size of each window for processing. |number| 30                     |
| task.window.shards                 | determines the number of parallel shards (instances) used for processing windows. It enables parallel processing of windows for improved scalability and performance.       |number| 1400                   |
| task.consumer.parallelism          | Parallelism for task consumers                        |number| 1                      |
| task.downstream.operators.parallelism | Parallelism for downstream operators               |number| 1                      |
## Router Job
| Configuration          | Description                                  |Data type| Default Value            |
|------------------------|----------------------------------------------|----|--------------------------|
| kafka.input.topic      | Input Kafka topic                            |string| dev.transform          |
| kafka.stats.topic      | Kafka topic for storing statistics           |string| dev.stats              |
| kafka.groupId          | Kafka consumer group ID                      |string| dev-druid-router-group |
| task.consumer.parallelism | Parallelism for task consumers             |number| 1                        |
| task.downstream.operators.parallelism | Parallelism for downstream operators   |number| 1                        |
## Kafka connector Job
| Configuration                      | Description                                        |Data type| Default Value                  |
|------------------------------------|----------------------------------------------------|----|--------------------------------|
| kafka.input.topic                  | Input Kafka topic                                  |string| dev.input                     |
| kafka.output.failed.topic          | Output Kafka topic for failed data                 |string| dev.failed                   |
| kafka.event.max.size               | Maximum size of events in bytes                    |number| 1048576 (1MB)                  |
| kafka.groupId                      | Kafka consumer group ID                            |string| dev-kafkaconnector-group     |
| kafka.producer.max-request-size    | Maximum request size for Kafka producer in bytes   |number| 5242880 (5MB)                  |
| task.consumer.parallelism          | Parallelism for task consumers                     |number| 1                              |
| task.downstream.operators.parallelism | Parallelism for downstream operators             |number|1                              |
## MasterData Processor Job
| Configuration                             | Description                                        | Data Type | Default Value                  |
|-------------------------------------------|----------------------------------------------------|-----------|--------------------------------|
| master-data-processor.kafka.input.topic     | Input Kafka topic                                  | String    | dev.masterdata.ingest |
| master-data-processor.kafka.output.raw.topic | Output Kafka topic for raw data                    | String    | dev.masterdata.raw |
| master-data-processor.kafka.output.extractor.duplicate.topic | Output Kafka topic for duplicate data extraction | String    | dev.masterdata.extractor.duplicate |
| master-data-processor.kafka.output.failed.topic | Output Kafka topic for failed data               | String    | dev.masterdata.failed |
| master-data-processor.kafka.output.batch.failed.topic | Output Kafka topic for batch extraction failures | String    | dev.masterdata.extractor.failed |
| master-data-processor.kafka.event.max.size | Maximum size of events in bytes                    | Number    | 1048576 (1MB) |
| master-data-processor.kafka.output.invalid.topic | Output Kafka topic for invalid data             | String    | dev.masterdata.invalid |
| master-data-processor.kafka.output.unique.topic | Output Kafka topic for unique data               | String    | dev.masterdata.unique |
| master-data-processor.kafka.output.duplicate.topic | Output Kafka topic for duplicate data           | String    | dev.masterdata.duplicate |
| master-data-processor.kafka.output.transform.topic | Output Kafka topic for transformed data         | String    | dev.masterdata.transform |
| master-data-processor.kafka.stats.topic       | Kafka topic for statistics data                    | String    | dev.masterdata.stats |
| master-data-processor.kafka.groupId           | Kafka consumer group ID                            | String    | dev-masterdata-pipeline-group |
| master-data-processor.kafka.producer.max-request-size | Maximum request size for Kafka producer      | Number    | 5242880 (5MB) |
| master-data-processor.task.window.time.in.seconds | Time window in seconds for tasks              | Number    | 5 |
| master-data-processor.task.window.count     | Count of events within the time window              | Number    | 30 |
| master-data-processor.task.window.shards    | Number of shards for the time window                | Number    | 1400 |
| master-data-processor.task.consumer.parallelism | Parallelism for task consumers                  | Number    | 1 |
| master-data-processor.task.downstream.operators.parallelism | Parallelism for downstream operators    | Number    | 1 |
| master-data-processor.redis.database.extractor.duplication.store.id | Redis store ID for extractor duplication  | Number    | 1 |
| master-data-processor.redis.database.preprocessor.duplication.store.id | Redis store ID for preprocessor duplication | Number    | 2 |
| master-data-processor.redis.database.key.expiry.seconds | Expiry time for Redis keys in seconds       | Number    | 3600 |
| master-data-processor.dataset.type           | Type of master dataset                                    | String    | master-dataset |

**Note**: If you require further assistance or have any questions, we encourage you to reach out for support. The [Sunbird Obsrv Github community](https://github.com/orgs/Sunbird-Obsrv/discussions) provides a platform to start discussions, seek solutions, and collaborate with others.