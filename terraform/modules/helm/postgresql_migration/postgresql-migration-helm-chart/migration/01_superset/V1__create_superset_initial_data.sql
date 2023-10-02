CREATE USER superset WITH ENCRYPTED PASSWORD '${postgresql_superset_user_password}';
GRANT ALL PRIVILEGES ON DATABASE superset TO superset;
