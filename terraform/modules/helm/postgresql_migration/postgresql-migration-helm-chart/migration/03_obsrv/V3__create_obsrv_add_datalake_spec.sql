ALTER TABLE datasources ALTER COLUMN ingestion_spec DROP NOT NULL;
ALTER TABLE datasources ADD COLUMN datalake_ingestion_spec JSON;