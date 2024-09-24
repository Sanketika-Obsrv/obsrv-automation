CREATE TABLE IF NOT EXISTS "query_templates" (
    "template_id" text NOT NULL,
    "template_name" text NOT NULL,
    "query" text NOT NULL,
    "query_type" text NOT NULL,
    "created_date" timestamp NOT NULL,
    "updated_date" timestamp NOT NULL,
    "created_by" text NOT NULL,
    "updated_by" text NOT NULL,
    PRIMARY KEY ("template_id")
);

ALTER TABLE datasets_draft 
  DROP COLUMN client_state,
  ADD COLUMN api_version VARCHAR(255) NOT NULL default 'v1', 
  ADD COLUMN version_key TEXT, 
  ADD COLUMN transformations_config JSON default '{}', 
  ADD COLUMN connectors_config JSON default '{}', 
  ADD COLUMN sample_data JSON default '{}', 
  ADD COLUMN entry_topic TEXT NOT NULL default '{{ .Values.global.env }}.ingest';
  
ALTER TABLE datasets 
  ADD COLUMN api_version VARCHAR(255) NOT NULL default 'v1', 
  ADD COLUMN version INTEGER NOT NULL default 1, 
  ADD COLUMN sample_data JSON default '{}',
  ADD COLUMN entry_topic TEXT NOT NULL default '{{ .Values.global.env }}.ingest';

UPDATE datasets_draft SET status = 'ReadyToPublish' WHERE status = 'Publish';
UPDATE datasets_draft SET type = 'event' WHERE type = 'dataset';
UPDATE datasets_draft SET type = 'master' WHERE type = 'master-dataset';
UPDATE datasets SET type = 'event' WHERE type = 'dataset';
UPDATE datasets SET type = 'master' WHERE type = 'master-dataset';

DELETE FROM dataset_transformations_draft where dataset_id in (SELECT dataset_id from datasets where status = 'Live');
DELETE FROM dataset_source_config_draft where dataset_id in (SELECT dataset_id from datasets where status = 'Live');
DELETE FROM datasources_draft where dataset_id in (SELECT dataset_id from datasets where status = 'Live');
DELETE FROM datasets_draft where dataset_id in (SELECT dataset_id from datasets where status = 'Live');

ALTER TABLE dataset_source_config_draft ALTER COLUMN published_date DROP NOT NULL;
ALTER TABLE datasets_draft ALTER COLUMN published_date DROP NOT NULL;
ALTER TABLE dataset_transformations_draft ALTER COLUMN published_date DROP NOT NULL;
ALTER TABLE datasources_draft ALTER COLUMN published_date DROP NOT NULL;

CREATE TABLE IF NOT EXISTS connector_registry (
  id TEXT NOT NULL PRIMARY KEY,
  connector_id TEXT NOT NULL,
  name TEXT NOT NULL,
  type TEXT NOT NULL,
  category TEXT NOT NULL,
  version TEXT NOT NULL,
  description TEXT,
  technology TEXT NOT NULL,
  runtime TEXT NOT NULL,
  licence TEXT NOT NULL,
  owner TEXT NOT NULL ,
  iconURL TEXT,
  status TEXT NOT NULL,
  ui_spec JSON NOT NULL DEFAULT '{}',
  source_url TEXT NOT NULL,
  source JSON NOT NULL,
  created_by text NOT NULL,
  updated_by text NOT NULL,
  created_date TIMESTAMP NOT NULL,
  updated_date TIMESTAMP NOT NULL,
  live_date TIMESTAMP,
  UNIQUE (connector_id, version)
);

CREATE TABLE IF NOT EXISTS connector_instances (
  id TEXT PRIMARY KEY,
  dataset_id TEXT NOT NULL REFERENCES datasets (id),
  connector_id TEXT NOT NULL REFERENCES connector_registry (id),
  data_format TEXT,
  connector_config TEXT NOT NULL,
  operations_config JSON NOT NULL,
  status TEXT NOT NULL,
  connector_state JSON NOT NULL DEFAULT '{}',
  connector_stats JSON NOT NULL DEFAULT '{}',
  created_by TEXT NOT NULL,
  updated_by TEXT NOT NULL,
  created_date TIMESTAMP NOT NULL,
  updated_date TIMESTAMP NOT NULL,
  published_date TIMESTAMP NOT NULL
);

ALTER TABLE datasources_draft
DROP CONSTRAINT IF EXISTS datasources_draft_dataset_id_datasource_key;

ALTER TABLE datasources_draft
ADD CONSTRAINT datasources_draft_dataset_id_datasource_type_key
UNIQUE (dataset_id, datasource, type);

ALTER TABLE datasources
DROP CONSTRAINT IF EXISTS datasources_dataset_id_datasource_key;

ALTER TABLE datasources
ADD CONSTRAINT datasources_dataset_id_datasource_type_key
UNIQUE (dataset_id, datasource, type);

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO obsrv;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO obsrv;

INSERT INTO
    connector_registry (
        id,
        connector_id,
        name,
        type,
        category,
        version,
        description,
        technology,
        runtime,
        licence,
        owner,
        iconURL,
        status,
        ui_spec,
        source_url,
        source,
        created_by,
        updated_by,
        created_date,
        updated_date,
        live_date
    )
VALUES
    (
        'kafka-connector-1.0.0',
        'kafka-connector',
        'Kafka Connector',
        'source',
        'Stream',
        '1.0.0',
        'Pull data from a Kafka Source',
        'scala',
        'flink',
        'MIT',
        'Sunbird',
        'iVBORw0KGgoAAAANSUhEUgAAAEAAAABACAQAAAAAYLlVAAAABGdBTUEAALGPC/xhBQAAACBjSFJNAAB6JgAAgIQAAPoAAACA6AAAdTAAAOpgAAA6mAAAF3CculE8AAAAAmJLR0QA/4ePzL8AAAAHdElNRQfoBxYFISBAqxDcAAAEsUlEQVRo3r2ZW2yURRTHf0svAoW22qYSsZootmrBaLk0KmrTxkBRrhGEplGoxvhi8EWraBCtokab+CBgfCHGUqMmCAlFJbGgIhEEqjG2orageGmFhdaylLZ014dODzPfpZSd/fZ8DzP7n/nm/Ge+mXPmnIXRSIgFNHCMc4Q5yEtcQ1JlCt8SM55eXmBMstRPJ+xQP/R8TEoy1Ofxp6f6GDFeTQaBTaIuzHqWUk2jIAMUBq0+mz6lrIWrBH2MqEI3Bk3gQZntdANvUOgf9ipG3ss3qLKVQw4CQ5LPuGAJZKryhAPvlFpWsAROqrLQ0a9IlVHCwe6BUtkDj2hoOj8o9GDQmzCdv5Sqs1QqLJftQqvGc01vZT6LKCE9ERSe0AxPK/Xs4Iz87nTtgGzW0yHtXbyjHd6498guHzt4nvmOviX87er1HwttKUygyUN9Hw85+s0g4kl0kMW2FFKo4ZQx6F6HYYIMjhur06f96kmE+86gWg3XSLFH+3Oi7icqSCXEHXwt2OZEbMcr1WBrPVt/Ua1HyBYsjT0KjdhbzJEJ5Mtclxn4bYKXxWcJRytXS63JwJs57eoRCIExvuOFVBmzU5DJKj6Sr1zL7a4VGF7qSgOfJXhp/MrHUkuX63Tv4y6tzz0MKLydXO3NfXIQx8arvoAffS3hy4SAdF5nUMN/YzHjSaOc7wR7N171hR7GVX/epojmEXsM+YQ4PcJ4Wi46+Hmp7XFYyws95sU7/zpjoEZWMpu5vCguWg9UVhNiGm2ullPMiT8iiGiLWGGszBZDSbPckMaxRiPRSZ22JS9ZnpSBotzrOvc7tehgousqW848ptramE+1IMwt12lfvzQxNswpN0vtA4/Wdg5IfVowBPKkdsSz/WfNTQVCoF+zaF5ywcGeC4ZAh9RmerbP9OiZUHlPNtn3HjTnaMewyO6+5yeX8YCqTSKF3Y7LyXa5+fRTR7fWNpklLKSMQs7YxU1pHNNmuYnLNd/Xbhii06xQLTex03BM++2OaJWhpoetvMkGH+dTTxaVxl142IittaHQcBFX1Ket0j/G3PWnxuYy0jiC+n4WMZHNHv7vMPvp1UKTYpvw9A2fmR3lTtVnqZFH26a8f7aWX2q0O5Cz+MRBooNnDReUL1eyr0j1OMoDXGFrFXJZrgZrosR1eAuEWrmBXyvprAp7w5SqhnrLo+1uIZDtSuYM4dXBxgURV1Zp2MxlqNrZYAn8TlTVlhj4XCHQHuwnQNLZXdyiGeWjcjmzzitnskINttuVGzCtZg+1zKaEp+T7x1hnO/c1jtjoG2a4PuVeX4PVxgS7uX/paYRXusL3Nk/1YabaXVi+8JnXIAtctuJzV6/DTLFb/tXaYC28zw565Pe/rlMP97FVJfL62EWV7SlLl9gwwnKF5bBNKDzj814OkyQzYCVlomqVQWv4TnAo6FTt0+J8zKV8WPZBWrDZ8lyJDKIG3iJv5wRLoNsVpDhDke5gCfyqyhsdhqdKlcfpDXYPZMk1s5XJgj4uW3MDgctGLdXwGst4lM+0O2FB8ATyjCS0+bxCUqSYk57qP0zev8fXS74vJn/gPJ8YSzdaCXE/9bTTywkOsM4/83vp8j/m7GxW4xTZpwAAACV0RVh0ZGF0ZTpjcmVhdGUAMjAyNC0wNy0yMlQwNTozMzozMSswMDowMA6dqVsAAAAldEVYdGRhdGU6bW9kaWZ5ADIwMjQtMDctMjJUMDU6MzM6MzErMDA6MDB/wBHnAAAAAElFTkSuQmCC',
        'Live',
        '{"schema": {"title": "Connector Config", "type": "object", "properties": {"source": {"title": "Storage Source", "type": "object", "properties": {"kafka-broker-servers": {"title": "Kafka Brokers", "type": "array", "items": {"type": "string", "pattern": "", "description": "Enter Kafka broker address in the format: host[:port]"}, "minItems": 1, "uniqueItems": true, "fieldDescription": [{"type": "string", "description": "List of Kafka broker addresses."}]}, "kafka-topic": {"title": "Kafka Topic", "type": "string", "pattern": "^[a-zA-Z0-9\\\\._\\\\-]+$", "description": "Enter Kafka topic name. Only alphanumeric characters, dots, dashes, and underscores are allowed.", "fieldDescription": [{"type": "string", "description": "Enter a valid kafka topic."}]}, "kafka-auto-offset-reset": {"title": "Kafka Auto Offset Reset", "type": "string", "description": "Select the suitable offset reset strategy.", "fieldDescription": [{"type": "string", "description": "The auto.offset.reset setting in Kafka determines what happens when there is no initial offset or if the current offset does not exist any longer on the server.\\n EARLIEST: Start consumption from the earliest available message in the topic.\\n LATEST: Start consumption from the latest message available in the topic.\\n NONE: Throw an error if no offset is found for the consumer group, requiring explicit offset assignment."}], "enum": ["EARLIEST", "LATEST", "NONE"]}, "kafka-consumer-id": {"title": "Kafka Consumer Id", "type": "string", "pattern": "^[a-zA-Z0-9\\\\._\\\\-]+$", "description": "Enter Kafka consumer group ID.", "fieldDescription": [{"type": "string", "description": "Select suitable offset."}]}}}}, "required": ["source"]}, "properties": {}}',
        'kafka-connector-1.0.0-distribution.tar.gz',
        '{"source": "kafka-connector-1.0.0", "main_class": "org.sunbird.obsrv.connector.KafkaConnector", "main_program": "kafka-connector-1.0.0.jar"}',
        'SYSTEM',
        'SYSTEM',
        NOW(),
        NOW(),
        NOW()
    );
