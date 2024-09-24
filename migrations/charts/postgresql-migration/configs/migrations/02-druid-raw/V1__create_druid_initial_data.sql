DO
$do$
BEGIN
   IF EXISTS (
      SELECT FROM pg_catalog.pg_roles
      WHERE  rolname = 'druid_raw') THEN

      RAISE NOTICE 'Role "druid_raw" already exists. Changing password...';
      BEGIN
         ALTER ROLE druid_raw WITH LOGIN PASSWORD '{{ tpl .Values.postgresql_druid_raw_user_password . }}';
      EXCEPTION
         WHEN insufficient_privilege THEN
            RAISE NOTICE 'Not enough privileges to alter role "druid_raw". Skipping.';
      END;
   ELSE
      BEGIN
         CREATE ROLE druid_raw LOGIN PASSWORD '{{ tpl .Values.postgresql_druid_raw_user_password . }}';
      EXCEPTION
         WHEN duplicate_object THEN
            RAISE NOTICE 'Role "druid_raw" was just created by a concurrent transaction. Skipping.';
      END;
   END IF;
END
$do$;

GRANT ALL PRIVILEGES ON DATABASE druid_raw TO druid_raw;
ALTER DATABASE druid_raw OWNER TO druid_raw;
