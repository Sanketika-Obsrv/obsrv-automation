ALTER TABLE datasources
  ADD COLUMN IF NOT EXISTS version INTEGER NOT NULL default 1,
  ADD COLUMN IF NOT EXISTS is_primary BOOLEAN,
  ADD COLUMN IF NOT EXISTS name TEXT;

UPDATE datasources SET is_primary = true, name = datasource;

ALTER TABLE connector_instances ADD COLUMN IF NOT EXISTS name TEXT;

ALTER TABLE oauth_users ADD COLUMN is_owner BOOLEAN DEFAULT FALSE;
UPDATE oauth_users SET is_owner=true WHERE user_name ='obsrv_admin';

UPDATE oauth_users SET roles='{admin}' WHERE user_name ='obsrv_admin';

ALTER TABLE oauth_users ADD COLUMN created_by TEXT DEFAULT 'SYSTEM';
ALTER TABLE oauth_users ADD COLUMN updated_by TEXT DEFAULT 'SYSTEM';

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO obsrv;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO obsrv;
