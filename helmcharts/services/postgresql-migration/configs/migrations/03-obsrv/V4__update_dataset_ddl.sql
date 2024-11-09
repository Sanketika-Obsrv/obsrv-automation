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
        '{"title":"Kafka Connector Setup Instructions","description":"Configure Kafka Connector","helptext":"Follow the below instructions to populate the required inputs needed for the connector correctly.","type":"object","properties":{"source_kafka_broker_servers":{"title":"Kafka Brokers","type":"string","description":"Enter Kafka broker addresses in the format: broker1-hostname:port,broker2-hostname:port","helptext":"<p><strong>Kafka Broker Address Format:</strong> Enter the broker addresses in the following format:<code>&lt;broker1-hostname&gt;:&lt;port&gt;,&lt;broker2-hostname&gt;:&lt;port&gt;,&lt;broker3-hostname&gt;:&lt;port&gt;</code></p><p><em>Example:</em> <code>broker1.example.com:9092,broker2.example.com:9092,broker3.example.com:9092</code></p><p>Ensure each brokers hostname and port are correct, separated by commas.</p>","uiIndex":1},"source_kafka_topic":{"title":"Kafka Topic","type":"string","pattern":"^[a-zA-Z0-9\\\\._\\\\-]+$","description":"Enter Kafka topic name. Only alphanumeric characters, dots, dashes, and underscores are allowed.","helptext":"<p>  <strong>Kafka Topic Name:</strong> Enter the name of the Kafka topic. Only alphanumeric characters (A-Z, 0-9), dots (<em>.</em>), dashes (<em>-</em>), and underscores (<em>_</em>) are allowed.</p><p>  <em>Example:</em> <em>example_topic-01</em></p><p>Ensure the topic name is clear and follows these character restrictions for compatibility with Kafka.</p>","uiIndex":2},"source_kafka_auto_offset_reset":{"title":"Kafka Auto Offset Reset","type":"string","description":"Select auto offset reset: earliest, latest, or none (default: earliest if unsure)","helptext":"<p>  <strong>Kafka Auto Offset Reset:</strong> Determines where the consumer begins reading if there’s no previous offset or the offset is out of range.</p><p>  <strong>Possible Values:</strong>  <ul>    <li><strong>earliest</strong> - Start from the earliest message (default). If unsure, leave this as <strong>earliest</strong>.</li>    <li><strong>latest</strong> - Start from the most recent message.</li>    <li><strong>none</strong> - Throw an error if no previous offset is found.</li>  </ul></p>","enum":["earliest","latest","none"],"default":"earliest","uiIndex":3},"source_kafka_consumer_id":{"title":"Kafka Consumer Id","type":"string","pattern":"^[a-zA-Z0-9\\\\._\\\\-]+$","description":"Enter Kafka consumer group ID (e.g., my_consumer_group_01)","helptext":"<p>  <strong>Kafka Consumer Group ID:</strong> Specify a unique identifier for the consumer group. This ID helps Kafka manage message consumption and track offsets across multiple consumers.</p><p>  <em>Note:</em> Choose a meaningful name for easy tracking, as consumers with the same group ID share messages.</p><p>  <em>Example:</em> <em>my_consumer_group_01</em></p>","default":"kafka-connector-group","uiIndex":4},"source_data_format":{"title":"Data Format","type":"string","enum":["json","jsonl","csv","parquet"],"description":"Select data format (e.g., json)","helptext":"<p><strong>Data Format:</strong> Select the format of the data stored in the kafka topic. Supported formats:</p><ul><li><strong>JSON:</strong> Standard JSON format, typically one object per file.<code>{<br/>&nbsp;&nbsp;\"id\": 1,<br/>&nbsp;&nbsp;\"name\": \"Alice\",<br/>&nbsp;&nbsp;\"email\": \"abc@xyz.com\"<br/>}</code></li><li><strong>JSONL:</strong> JSON Lines format with one JSON object per line, suitable for large datasets.<code>{\"id\": 1, \"name\": \"Alice\", \"email\": \"alice@example.com\"}<br/>{\"id\": 2, \"name\": \"Bob\", \"email\": \"bob@example.com\"}</code></li><li><strong>Parquet:</strong> A binary, columnar format optimized for efficient storage. Not human-readable.</li><li><strong>CSV:</strong> Comma-separated values format for tabular data.<code>id,name,email<br/>1,Alice,alice@example.com<br/>2,Bob,bob@example.com</code></li></ul><p>Select the format that matches the data files in the bucket.</p>","default":"json","format":"hidden","uiIndex":5}},"required":["source_kafka_broker_servers","source_kafka_topic","source_kafka_consumer_id","source_kafka_auto_offset_reset","source_data_format"]}',
        'kafka-connector-1.0.0-distribution.tar.gz',
        '{"source": "kafka-connector-1.0.0", "main_class": "org.sunbird.obsrv.connector.KafkaConnector", "main_program": "kafka-connector-1.0.0.jar"}',
        'SYSTEM',
        'SYSTEM',
        NOW(),
        NOW(),
        NOW()
    );
ALTER TABLE oauth_users ADD COLUMN roles TEXT[] DEFAULT ARRAY['viewer'];
ALTER TABLE oauth_users ADD COLUMN status VARCHAR(255) DEFAULT 'active';
ALTER TABLE oauth_users ADD CONSTRAINT oauth_users_user_name_key UNIQUE (user_name);
