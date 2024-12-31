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

ALTER TABLE oauth_users ADD COLUMN roles TEXT[] DEFAULT ARRAY['viewer'];
ALTER TABLE oauth_users ADD COLUMN status VARCHAR(255) DEFAULT 'active';
ALTER TABLE oauth_users ADD CONSTRAINT oauth_users_user_name_key UNIQUE (user_name);
