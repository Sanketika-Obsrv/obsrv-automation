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
        'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMTU0IiBoZWlnaHQ9IjI1MCIgdmlld0JveD0iMCAwIDI1NiA0MTYiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIgcHJlc2VydmVBc3BlY3RSYXRpbz0ieE1pZFlNaWQiPjxwYXRoIGQ9Ik0yMDEuODE2IDIzMC4yMTZjLTE2LjE4NiAwLTMwLjY5NyA3LjE3MS00MC42MzQgMTguNDYxbC0yNS40NjMtMTguMDI2YzIuNzAzLTcuNDQyIDQuMjU1LTE1LjQzMyA0LjI1NS0yMy43OTcgMC04LjIxOS0xLjQ5OC0xNi4wNzYtNC4xMTItMjMuNDA4bDI1LjQwNi0xNy44MzVjOS45MzYgMTEuMjMzIDI0LjQwOSAxOC4zNjUgNDAuNTQ4IDE4LjM2NSAyOS44NzUgMCA1NC4xODQtMjQuMzA1IDU0LjE4NC01NC4xODQgMC0yOS44NzktMjQuMzA5LTU0LjE4NC01NC4xODQtNTQuMTg0LTI5Ljg3NSAwLTU0LjE4NCAyNC4zMDUtNTQuMTg0IDU0LjE4NCAwIDUuMzQ4LjgwOCAxMC41MDUgMi4yNTggMTUuMzg5bC0yNS40MjMgMTcuODQ0Yy0xMC42Mi0xMy4xNzUtMjUuOTExLTIyLjM3NC00My4zMzMtMjUuMTgydi0zMC42NGMyNC41NDQtNS4xNTUgNDMuMDM3LTI2Ljk2MiA0My4wMzctNTMuMDE5QzEyNC4xNzEgMjQuMzA1IDk5Ljg2MiAwIDY5Ljk4NyAwIDQwLjExMiAwIDE1LjgwMyAyNC4zMDUgMTUuODAzIDU0LjE4NGMwIDI1LjcwOCAxOC4wMTQgNDcuMjQ2IDQyLjA2NyA1Mi43Njl2MzEuMDM4QzI1LjA0NCAxNDMuNzUzIDAgMTcyLjQwMSAwIDIwNi44NTRjMCAzNC42MjEgMjUuMjkyIDYzLjM3NCA1OC4zNTUgNjguOTR2MzIuNzc0Yy0yNC4yOTkgNS4zNDEtNDIuNTUyIDI3LjAxMS00Mi41NTIgNTIuODk0IDAgMjkuODc5IDI0LjMwOSA1NC4xODQgNTQuMTg0IDU0LjE4NCAyOS44NzUgMCA1NC4xODQtMjQuMzA1IDU0LjE4NC01NC4xODQgMC0yNS44ODMtMTguMjUzLTQ3LjU1My00Mi41NTItNTIuODk0di0zMi43NzVhNjkuOTY1IDY5Ljk2NSAwIDAgMCA0Mi42LTI0Ljc3NmwyNS42MzMgMTguMTQzYy0xLjQyMyA0Ljg0LTIuMjIgOS45NDYtMi4yMiAxNS4yNCAwIDI5Ljg3OSAyNC4zMDkgNTQuMTg0IDU0LjE4NCA1NC4xODQgMjkuODc1IDAgNTQuMTg0LTI0LjMwNSA1NC4xODQtNTQuMTg0IDAtMjkuODc5LTI0LjMwOS01NC4xODQtNTQuMTg0LTU0LjE4NHptMC0xMjYuNjk1YzE0LjQ4NyAwIDI2LjI3IDExLjc4OCAyNi4yNyAyNi4yNzFzLTExLjc4MyAyNi4yNy0yNi4yNyAyNi4yNy0yNi4yNy0xMS43ODctMjYuMjctMjYuMjdjMC0xNC40ODMgMTEuNzgzLTI2LjI3MSAyNi4yNy0yNi4yNzF6bS0xNTguMS00OS4zMzdjMC0xNC40ODMgMTEuNzg0LTI2LjI3IDI2LjI3MS0yNi4yN3MyNi4yNyAxMS43ODcgMjYuMjcgMjYuMjdjMCAxNC40ODMtMTEuNzgzIDI2LjI3LTI2LjI3IDI2LjI3cy0yNi4yNzEtMTEuNzg3LTI2LjI3MS0yNi4yN3ptNTIuNTQxIDMwNy4yNzhjMCAxNC40ODMtMTEuNzgzIDI2LjI3LTI2LjI3IDI2LjI3cy0yNi4yNzEtMTEuNzg3LTI2LjI3MS0yNi4yN2MwLTE0LjQ4MyAxMS43ODQtMjYuMjcgMjYuMjcxLTI2LjI3czI2LjI3IDExLjc4NyAyNi4yNyAyNi4yN3ptLTI2LjI3Mi0xMTcuOTdjLTIwLjIwNSAwLTM2LjY0Mi0xNi40MzQtMzYuNjQyLTM2LjYzOCAwLTIwLjIwNSAxNi40MzctMzYuNjQyIDM2LjY0Mi0zNi42NDIgMjAuMjA0IDAgMzYuNjQxIDE2LjQzNyAzNi42NDEgMzYuNjQyIDAgMjAuMjA0LTE2LjQzNyAzNi42MzgtMzYuNjQxIDM2LjYzOHptMTMxLjgzMSA2Ny4xNzljLTE0LjQ4NyAwLTI2LjI3LTExLjc4OC0yNi4yNy0yNi4yNzFzMTEuNzgzLTI2LjI3IDI2LjI3LTI2LjI3IDI2LjI3IDExLjc4NyAyNi4yNyAyNi4yN2MwIDE0LjQ4My0xMS43ODMgMjYuMjcxLTI2LjI3IDI2LjI3MXoiIHN0eWxlPSJmaWxsOiMyMzFmMjAiLz48L3N2Zz4K',
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
