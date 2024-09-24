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

ALTER TABLE datasets_draft ADD COLUMN api_version VARCHAR(255);

ALTER TABLE datasets_draft ADD COLUMN version_key TEXT;

UPDATE datasets_draft
SET status = 'ReadyToPublish'
WHERE status = 'Publish';

ALTER TABLE dataset_source_config_draft ALTER COLUMN published_date DROP NOT NULL;
ALTER TABLE datasets_draft ALTER COLUMN published_date DROP NOT NULL;
ALTER TABLE dataset_transformations_draft ALTER COLUMN published_date DROP NOT NULL;
ALTER TABLE datasources_draft ALTER COLUMN published_date DROP NOT NULL;