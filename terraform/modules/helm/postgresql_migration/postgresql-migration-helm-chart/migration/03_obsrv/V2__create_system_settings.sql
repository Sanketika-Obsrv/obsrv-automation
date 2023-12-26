CREATE TABLE IF NOT EXISTS system_settings (
  "key" TEXT NOT NULL,
  "value" TEXT NOT NULL,
  category TEXT NOT NULL DEFAULT 'SYSTEM'::text,
  valuetype TEXT NOT NULL,
  created_date TIMESTAMP NOT NULL DEFAULT now(),
  updated_date TIMESTAMP,
  label TEXT,
  PRIMARY KEY ("key")
);

INSERT INTO system_settings VALUES 
   ('encryptionSecretKey', '{{ .Values.system_settings.encryption_key }}', 'SYSTEM', 'string', now(), now(), 'Data Encryption Secret Key'),
   ('defaultDatasetId', '{{ .Values.system_settings.default_dataset_id }}', 'SYSTEM', 'string', now(), now(), 'Default Dataset ID'),
   ('maxEventSize', '{{ .Values.system_settings.max_event_size }}', 'SYSTEM', 'long', now(), now(), 'Maximum Event Size (per event)'),
   ('defaultDedupPeriodInSeconds', '{{ .Values.system_settings.dedup_period }}', 'SYSTEM', 'int', now(), now(), 'Default Dedup Period (in seconds)');

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO obsrv;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO obsrv;
