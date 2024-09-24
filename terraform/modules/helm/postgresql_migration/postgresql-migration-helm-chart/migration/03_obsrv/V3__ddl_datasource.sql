ALTER TABLE datasources_draft ADD COLUMN type TEXT not NULL DEFAULT 'druid';
ALTER TABLE datasources ADD COLUMN type TEXT not NULL DEFAULT 'druid';