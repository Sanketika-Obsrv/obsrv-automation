DO
$do$
BEGIN
   IF EXISTS (
      SELECT FROM pg_catalog.pg_roles
      WHERE  rolname = 'keycloak') THEN

      RAISE NOTICE 'Role "keycloak" already exists. Changing password...';
      BEGIN
         ALTER ROLE keycloak WITH LOGIN PASSWORD '{{ tpl .Values.postgresql_keycloak_user_password . }}';
      EXCEPTION
         WHEN insufficient_privilege THEN
            RAISE NOTICE 'Not enough privileges to alter role "keycloak". Skipping.';
      END;
   ELSE
      BEGIN
         CREATE ROLE keycloak LOGIN PASSWORD '{{ tpl .Values.postgresql_keycloak_user_password . }}';
      EXCEPTION
         WHEN duplicate_object THEN
            RAISE NOTICE 'Role "keycloak" was just created by a concurrent transaction. Skipping.';
      END;
   END IF;
END
$do$;

GRANT ALL PRIVILEGES ON DATABASE keycloak TO keycloak;
ALTER DATABASE keycloak OWNER TO keycloak;
