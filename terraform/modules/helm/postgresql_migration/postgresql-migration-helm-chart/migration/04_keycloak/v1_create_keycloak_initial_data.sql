DO
$do$
BEGIN
   IF EXISTS (
      SELECT FROM pg_catalog.pg_roles
      WHERE  rolname = 'keycloak') THEN

      RAISE NOTICE 'Role "keycloak" already exists. Skipping.';
   ELSE
      BEGIN
         CREATE ROLE keycloak LOGIN PASSWORD '{{ .Values.keycloak_user_password }}';
      EXCEPTION
         WHEN duplicate_object THEN
            RAISE NOTICE 'Role "keycloak" was just created by a concurrent transaction. Skipping.';
      END;
   END IF;
END
$do$;

GRANT ALL PRIVILEGES ON DATABASE keycloak TO keycloak;
