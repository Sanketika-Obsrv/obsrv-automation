# Master Dataset 
A Master Dataset is an entity that holds your lookup data. It is structurally similar to a Dataset, except that it doesn't get indexed in the analytical store but in a cache store for fast lookups while ingesting data.  
In the dataset_config, you will need to specify the field name on which denorms will happen. For e.g.  
```
"dataset_config": {
    "data_key": ""
}
```
Once a Master Dataset is indexed, any Dataset can specify it in the denorm config. For e.g.
```
"denorm_config": {
    "redis_db_host": "localhost",
    "redis_db_port": 6379,
    "denorm_fields": [{
        "denorm_key": "assetRef", # the field in Dataset on which denorm needs to happen
        "redis_db": 3, # cache store index for Master Dataset
        "denorm_out_field": "asset_metadata" # the name to give the new field
    }]
}
```

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

To populate a Dataset, you can also use APIs.
### Data In API
**Endpoint**: `/obsrv/v1/data/{datasetId}`  
**Method**: `POST`  