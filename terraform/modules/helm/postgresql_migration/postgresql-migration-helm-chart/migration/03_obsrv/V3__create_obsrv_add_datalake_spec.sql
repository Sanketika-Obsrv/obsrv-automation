ALTER TABLE datasources ADD COLUMN type TEXT;

UPDATE datasources SET type = 'druid' WHERE type IS NULL;