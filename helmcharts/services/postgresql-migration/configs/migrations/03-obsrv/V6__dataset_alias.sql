ALTER TABLE datasets ADD COLUMN alias TEXT;
CREATE UNIQUE INDEX unique_alias ON datasets (alias) WHERE alias IS NOT NULL;