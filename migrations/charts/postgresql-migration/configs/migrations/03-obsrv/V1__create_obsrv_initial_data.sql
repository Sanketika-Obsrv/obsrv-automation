DO
$do$
BEGIN
   IF EXISTS (
      SELECT FROM pg_catalog.pg_roles
      WHERE  rolname = 'obsrv') THEN

      RAISE NOTICE 'Role "obsrv" already exists. Changing Password...';
      BEGIN
         ALTER ROLE obsrv WITH LOGIN PASSWORD '{{ tpl .Values.postgresql_obsrv_user_password . }}';
      EXCEPTION
         WHEN insufficient_privilege THEN
            RAISE NOTICE 'Not enough privileges to alter role "obsrv". Skipping.';
      END;
   ELSE
      BEGIN
         CREATE ROLE obsrv LOGIN PASSWORD '{{ tpl .Values.postgresql_obsrv_user_password . }}';
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
    tags TEXT[],
    data_version INT,
    status TEXT,
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

CREATE INDEX IF NOT EXISTS  dataset_source_config_dataset ON dataset_source_config (dataset_id);

CREATE INDEX IF NOT EXISTS dataset_source_config_status ON dataset_source_config (status);

CREATE TABLE IF NOT EXISTS datasets_draft (
  id TEXT PRIMARY KEY,
  dataset_id TEXT,
  version INTEGER NOT NULL,
  type TEXT NOT NULL,
  name TEXT,
  validation_config JSON,
  extraction_config JSON,
  dedup_config JSON,
  data_schema JSON,
  denorm_config JSON,
  router_config JSON,
  dataset_config JSON,
  client_state JSON,
  tags TEXT[],
  status TEXT,
  created_by TEXT,
  updated_by TEXT,
  created_date TIMESTAMP NOT NULL DEFAULT now(),
  updated_date TIMESTAMP NOT NULL,
  published_date TIMESTAMP NOT NULL DEFAULT now(),
  UNIQUE (dataset_id, version)
);

CREATE INDEX datasets_draft_status ON datasets_draft (status);

CREATE TABLE IF NOT EXISTS datasources_draft (
  id TEXT PRIMARY KEY,
  datasource text NOT NULL,
  dataset_id TEXT NOT NULL REFERENCES datasets_draft (id),
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

CREATE INDEX IF NOT EXISTS datasources_draft_dataset ON datasources_draft(dataset_id);

CREATE INDEX IF NOT EXISTS datasources_draft_status ON datasources_draft(status);

CREATE TABLE IF NOT EXISTS dataset_transformations_draft (
  id TEXT PRIMARY KEY,
  dataset_id TEXT NOT NULL REFERENCES datasets_draft (id),
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

CREATE INDEX IF NOT EXISTS dataset_transformations_draft_dataset ON dataset_transformations_draft (dataset_id);

CREATE INDEX IF NOT EXISTS dataset_transformations_draft_status ON dataset_transformations_draft (status);

CREATE TABLE IF NOT EXISTS dataset_source_config_draft (
  id TEXT PRIMARY KEY,
  dataset_id TEXT NOT NULL REFERENCES datasets_draft (id),
  connector_type text NOT NULL,
  connector_config json NOT NULL,
  status text NOT NULL,
  connector_stats JSON,
  created_by text NOT NULL,
  updated_by text NOT NULL,
  created_date TIMESTAMP NOT NULL DEFAULT now(),
  updated_date TIMESTAMP NOT NULL,
  published_date TIMESTAMP NOT NULL DEFAULT now(),
  UNIQUE(connector_type, dataset_id)
);

CREATE INDEX IF NOT EXISTS  dataset_source_config_draft_dataset ON dataset_source_config_draft (dataset_id);

CREATE INDEX IF NOT EXISTS dataset_source_config_draft_status ON dataset_source_config_draft (status);

CREATE TABLE IF NOT EXISTS connector_objects_info (
    "id" text PRIMARY KEY,
    "connector_id" text,
    "dataset_id" text,
    "status" text NOT NULL,
    "location" text,
    "format" text,
    "file_size_kb" int8,
    "in_time" timestamp DEFAULT now(),
    "download_time" int8,
    "start_processing_time" timestamp DEFAULT now(),
    "end_processing_time" timestamp DEFAULT now(),
    "file_hash" text,
    "num_of_retries" int4,
    "created_by" text DEFAULT 'SYSTEM'::text,
    "updated_by" text DEFAULT 'SYSTEM'::text,
    "created_at" timestamp DEFAULT now(),
    "updated_at" timestamp DEFAULT now(),
    "tags" _text
);

CREATE TABLE IF NOT EXISTS system_settings (
  "key" text NOT NULL,
  "value" text NOT NULL,
  "category" text NOT NULL DEFAULT 'SYSTEM'::text,
  "type" text NOT NULL,
  "created_date" timestamp NOT NULL DEFAULT now(),
  "updated_date" timestamp,
  "label" text,
  PRIMARY KEY ("key")
);

CREATE TABLE IF NOT EXISTS "user_session" (
  "sid" varchar NOT NULL COLLATE "default",
  "sess" json NOT NULL,
  "expire" timestamp(6) NOT NULL
)
WITH (OIDS=FALSE);

ALTER TABLE "user_session" ADD CONSTRAINT "session_pkey" PRIMARY KEY ("sid") NOT DEFERRABLE INITIALLY IMMEDIATE;

CREATE INDEX "IDX_session_expire" ON "user_session" ("expire");


CREATE TABLE IF NOT EXISTS "oauth_access_tokens" (
  id VARCHAR(255) PRIMARY KEY,
  user_id VARCHAR(255),
  client_id VARCHAR(255),
  created_on TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS "oauth_refresh_tokens" (
  id VARCHAR(255) PRIMARY KEY,
  user_id VARCHAR(255),
  client_id VARCHAR(255),
  created_on TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


CREATE TABLE IF NOT EXISTS "oauth_authorization_codes" (
  id VARCHAR(255) PRIMARY KEY,
  client_id VARCHAR(255),
  redirect_uri VARCHAR(255),
  user_id VARCHAR(255),
  user_name VARCHAR(255),
  created_on TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


CREATE TABLE IF NOT EXISTS "oauth_clients" (
  id VARCHAR(255) PRIMARY KEY,
  name VARCHAR(255),
  client_id VARCHAR(255) UNIQUE,
  client_secret VARCHAR(255),
  redirect_uri VARCHAR(255),
  is_trusted BOOLEAN,
  created_on TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  last_updated_on TIMESTAMP NULL
);

INSERT INTO "public"."oauth_clients" ("id", "name", "client_id", "client_secret", "redirect_uri", "is_trusted", "created_on", "last_updated_on")
VALUES ('1', 'Superset ', '{{ .Values.superset_oauth_clientid }}', '{{ .Values.superset_oauth_client_secret }}', 'https://{{ tpl .Values.kong_ingress_domain . }}/oauth-authorized/obsrv', 't', '2023-07-04 10:12:08.913786', NULL)
ON CONFLICT(id) DO
  UPDATE SET
  client_id = '{{ .Values.superset_oauth_clientid }}',
  client_secret = '{{ .Values.superset_oauth_client_secret }}',
  redirect_uri = 'https://{{ tpl .Values.kong_ingress_domain . }}/oauth-authorized/obsrv';


INSERT INTO "public"."oauth_clients" ("id", "name", "client_id", "client_secret", "redirect_uri", "is_trusted", "created_on", "last_updated_on")
VALUES ('2', 'Grafana', '{{ .Values.gf_auth_generic_oauth_client_id }}', '{{ .Values.gf_auth_generic_oauth_client_secret }}', 'https://{{ tpl .Values.kong_ingress_domain . }}/grafana/login/generic_oauth', 't', '2023-07-04 10:12:08.904986', NULL)
ON CONFLICT(id) DO
  UPDATE SET
  client_id = '{{ .Values.gf_auth_generic_oauth_client_id }}',
  client_secret = '{{ .Values.gf_auth_generic_oauth_client_secret }}',
  redirect_uri = 'https://{{ tpl .Values.kong_ingress_domain . }}/grafana/login/generic_oauth';

CREATE TABLE IF NOT EXISTS "oauth_users" (
  id VARCHAR(255) PRIMARY KEY,
  user_name VARCHAR(255),
  password VARCHAR(255) NULL,
  first_name VARCHAR(255) NULL,
  last_name VARCHAR(255) NULL,
  provider VARCHAR(255) NULL,
  email_address VARCHAR(255) UNIQUE,
  mobile_number VARCHAR(255) NULL,
  created_on TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  last_updated_on TIMESTAMP NULL
  );

CREATE TABLE IF NOT EXISTS "alerts" (
  "id" varchar NOT NULL,
  "manager" varchar,
  "name" varchar,
  "status" varchar,
  "description" varchar,
  "expression" varchar,
  "severity" varchar,
  "category" varchar,
  "annotations" json DEFAULT '{}'::json,
  "labels" json DEFAULT '{}'::json,
  "frequency" varchar DEFAULT '1m'::character varying,
  "interval" varchar DEFAULT '1m'::character varying,
  "metadata" json DEFAULT '{}'::json,
  "created_by" varchar DEFAULT 'SYSTEM'::character varying,
  "updated_by" varchar DEFAULT 'SYSTEM'::character varying,
  "createdAt" timestamptz NOT NULL,
  "updatedAt" timestamptz NOT NULL,
  "context" json DEFAULT '{}'::json,
  "notification" json DEFAULT '{}'::json,
  PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "notificationChannel" (
    "id" varchar NOT NULL,
    "manager" varchar,
    "name" varchar,
    "status" varchar,
    "type" varchar,
    "config" json DEFAULT '{}'::json,
    "created_by" varchar DEFAULT 'SYSTEM'::character varying,
    "updated_by" varchar DEFAULT 'SYSTEM'::character varying,
    "createdAt" timestamptz NOT NULL,
    "updatedAt" timestamptz NOT NULL,
    "context" json DEFAULT '{}'::json,
    PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "metrics" (
    "id" varchar NOT NULL,
    "alias" varchar UNIQUE,
    "component" varchar,
    "metric" varchar,
    "context" json DEFAULT '{}'::json,
    "createdAt" timestamptz NOT NULL,
    "updatedAt" timestamptz NOT NULL,
    "subComponent" varchar,
    PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "silences" (
    "id" text NOT NULL,
    "manager" text NOT NULL,
    "alert_id" text NOT NULL,
    "created_by" text NOT NULL,
    "updated_by" text NOT NULL,
    "start_time" timestamptz NOT NULL,
    "end_time" timestamptz NOT NULL,
    "context" json DEFAULT '{}'::json,
    "createdAt" timestamptz NOT NULL,
    "updatedAt" timestamptz NOT NULL,
    PRIMARY KEY ("id")
);

CREATE SEQUENCE redis_db_index START 3;

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO obsrv;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO obsrv;

INSERT INTO "oauth_users" ("id", "user_name", "password", "first_name", "last_name", "email_address", "created_on", "last_updated_on")
VALUES ('1', 'obsrv_admin', '{{ .Values.web_console_password }}', 'obsrv', 'admin', '{{ .Values.web_console_login }}', NOW(), NOW())
ON CONFLICT(id) DO
  UPDATE SET
  password = '{{ .Values.web_console_password }}',
  email_address = '{{ .Values.web_console_login }}';
