# Dataset 
A Dataset is an entity that holds your data. In order to ingest the data into Obsrv, we require the JSON schema of the data. 
You can specify various configurations while creating a Dataset, like what validations to make, how to extract batch data, which fields to check for duplication, and so on. In order to have denorm fields, please first create a Master Dataset and ingest some data in it.

For a full list of examples and schemas to all APIs, please see [obsrv Swagger Documentation](https://github.com/Sunbird-Obsrv/obsrv-api-service/blob/main/swagger-doc/openapi.yaml).
You can preview the yaml file in https://editor.swagger.io/

### Create Dataset API:
**Endpoint**: `/obsrv/v1/dataset/dataschema`  
**Method**: `POST`  

You can describe, list or update any of the active Datasets  
### Get Dataset API:
**Endpoint**: `/obsrv/v1/datasets/{datasetId}`  
**Method**: `GET`  
### List Dataset API:
**Endpoint**: `/obsrv/v1/datasets/list`  
**Method**: `POST`  
### Update Dataset API:
**Endpoint**: `/obsrv/v1/datasets`  
**Method**: `PATCH`  

## Data Ingestion
To populate a Dataset, you can also use APIs.
### Data In API
**Endpoint**: `/obsrv/v1/data/{datasetId}`  
**Method**: `POST`  

To query against a Dataset, you can use the native Druid query syntax, or SQL syntax
### Query API
**Endpoint**: `/obsrv/v1/query`  
**Method**: `POST`  
### SQL Query API
**Endpoint**: `/obsrv/v1/sql-query`  
**Method**: `POST`  