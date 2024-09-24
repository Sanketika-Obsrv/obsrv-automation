ALTER TABLE dataset_transformations_draft ADD mode TEXT, ADD metadata JSON; 
ALTER TABLE dataset_transformations ADD mode TEXT, ADD metadata JSON;
ALTER TABLE system_settings RENAME COLUMN "type" TO valuetype;
INSERT INTO system_settings VALUES 
   ('encryptionSecretKey', '{{ .Values.system_settings.encryption_key }}', 'SYSTEM', 'string', now(), now(), 'Data Encryption Secret Key'),
   ('defaultDatasetId', '{{ .Values.system_settings.default_dataset_id }}', 'SYSTEM', 'string', now(), now(), 'Default Dataset ID'),
   ('maxEventSize', '{{ .Values.system_settings.max_event_size }}', 'SYSTEM', 'long', now(), now(), 'Maximum Event Size (per event)'),
   ('defaultDedupPeriodInSeconds', '{{ .Values.system_settings.dedup_period }}', 'SYSTEM', 'int', now(), now(), 'Default Dedup Period (in seconds)') ON CONFLICT DO NOTHING;
