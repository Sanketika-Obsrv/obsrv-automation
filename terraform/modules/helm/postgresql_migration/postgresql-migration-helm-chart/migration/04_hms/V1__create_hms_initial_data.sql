DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'hms') THEN
        CREATE DATABASE hms;
    END IF;
END $$;

DO
$do$
BEGIN
   IF EXISTS (
      SELECT FROM pg_catalog.pg_roles
      WHERE  rolname = 'hms') THEN

      RAISE NOTICE 'Role "hms" already exists. Skipping.';
   ELSE
      BEGIN
         CREATE ROLE hms LOGIN PASSWORD '{{ .Values.postgresql_hms_user_password }}';
      EXCEPTION
         WHEN duplicate_object THEN
            RAISE NOTICE 'Role "hms" was just created by a concurrent transaction. Skipping.';
      END;
   END IF;
END
$do$;

GRANT ALL PRIVILEGES ON DATABASE hms TO hms;
ALTER DATABASE hms OWNER TO hms;
