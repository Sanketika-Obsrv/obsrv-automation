DO
$do$
BEGIN
   IF EXISTS (
      SELECT FROM pg_catalog.pg_roles
      WHERE  rolname = 'superset') THEN

      RAISE NOTICE 'Role "superset" already exists. Skipping.';
   ELSE
      BEGIN
         CREATE ROLE superset LOGIN PASSWORD '{{ .Values.postgresql_superset_user_password }}';
      EXCEPTION
         WHEN duplicate_object THEN
            RAISE NOTICE 'Role "superset" was just created by a concurrent transaction. Skipping.';
      END;
   END IF;
END
$do$;

GRANT ALL PRIVILEGES ON DATABASE superset TO superset;
