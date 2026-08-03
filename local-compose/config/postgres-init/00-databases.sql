-- Mirrors helmcharts/global-values.yaml -> postgresql.primary.initdb.scripts.
--
-- IMPORTANT: databases only. Roles (obsrv, druid_raw, keycloak) and all schema
-- are created by the Flyway migrations in
-- helmcharts/services/postgresql-migration/configs/migrations/, exactly as in
-- the helm install. Creating the roles here too would fight those migrations.
--
-- Dropped vs the chart: superset and hms databases, both out of scope for a
-- core+console stack.

CREATE DATABASE druid_raw;
CREATE DATABASE obsrv;
CREATE DATABASE keycloak;
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
