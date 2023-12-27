DO
$do$
BEGIN
   IF EXISTS (
      SELECT FROM pg_catalog.pg_roles
      WHERE  rolname = 'obsrv') THEN

      RAISE NOTICE 'Role "obsrv" already exists. Skipping.';
   ELSE
      BEGIN
         CREATE ROLE obsrv LOGIN PASSWORD '{{ .Values.postgresql_obsrv_user_password }}';
      EXCEPTION
         WHEN duplicate_object THEN
            RAISE NOTICE 'Role "obsrv" was just created by a concurrent transaction. Skipping.';
      END;
   END IF;
END
$do$;

ALTER DATABASE obsrv OWNER TO obsrv;

GRANT ALL PRIVILEGES ON DATABASE obsrv TO obsrv;

CREATE TABLE IF NOT EXISTS datasets (
    id TEXT PRIMARY KEY,
    dataset_id TEXT,
    type TEXT NOT NULL,
    name TEXT,
    validation_config JSON,
    extraction_config JSON,
    dedup_config JSON,
    data_schema JSON,
    denorm_config JSON,
    router_config JSON,
    dataset_config JSON,
    status TEXT,
    tags TEXT[],
    data_version INT,
    created_by TEXT,
    updated_by TEXT,
    created_date TIMESTAMP NOT NULL DEFAULT now(),
    updated_date TIMESTAMP NOT NULL,
    published_date TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS datasets_status ON datasets(status);

CREATE TABLE IF NOT EXISTS datasources (
  id TEXT PRIMARY KEY,
  datasource text NOT NULL,
  dataset_id TEXT NOT NULL REFERENCES datasets (id),
  ingestion_spec json NOT NULL,
  datasource_ref text NOT NULL,
  retention_period json,
  archival_policy json,
  purge_policy json,
  backup_config json NOT NULL,
  metadata json,
  status text NOT NULL,
  created_by text NOT NULL,
  updated_by text NOT NULL,
  created_date TIMESTAMP NOT NULL DEFAULT now(),
  updated_date TIMESTAMP NOT NULL,
  published_date TIMESTAMP NOT NULL DEFAULT now(),
  UNIQUE (dataset_id, datasource)
);

CREATE INDEX IF NOT EXISTS datasources_dataset ON datasources(dataset_id);

CREATE INDEX IF NOT EXISTS datasources_status ON datasources(status);

CREATE TABLE IF NOT EXISTS dataset_transformations (
  id TEXT PRIMARY KEY,
  dataset_id TEXT NOT NULL REFERENCES datasets (id),
  field_key TEXT NOT NULL,
  transformation_function JSON,
  status TEXT NOT NULL,
  created_by TEXT NOT NULL,
  updated_by TEXT NOT NULL,
  created_date TIMESTAMP NOT NULL DEFAULT now(),
  updated_date TIMESTAMP NOT NULL,
  published_date TIMESTAMP NOT NULL DEFAULT now(),
  UNIQUE (dataset_id, field_key)
);

CREATE INDEX IF NOT EXISTS dataset_transformations_dataset ON dataset_transformations (dataset_id);

CREATE INDEX IF NOT EXISTS dataset_transformations_status ON dataset_transformations (status);

CREATE TABLE IF NOT EXISTS dataset_source_config (
  id TEXT PRIMARY KEY,
  dataset_id TEXT NOT NULL REFERENCES datasets (id),
  connector_type text NOT NULL,
  connector_config json NOT NULL,
  status text NOT NULL,
  connector_stats json,
  created_by text NOT NULL,
  updated_by text NOT NULL,
  created_date TIMESTAMP NOT NULL DEFAULT now(),
  updated_date TIMESTAMP NOT NULL,
  published_date TIMESTAMP NOT NULL DEFAULT now(),
  UNIQUE(connector_type, dataset_id)
);

CREATE INDEX IF NOT EXISTS  dataset_source_config_dataset ON dataset_source_config(dataset_id);

CREATE INDEX IF NOT EXISTS dataset_source_config_status ON dataset_source_config(status);

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO obsrv;

GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO obsrv;
