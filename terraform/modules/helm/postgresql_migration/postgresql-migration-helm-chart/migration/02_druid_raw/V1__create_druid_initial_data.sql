CREATE USER druid_raw WITH ENCRYPTED PASSWORD '${postgresql_druid_raw_user_password}';
GRANT ALL PRIVILEGES ON DATABASE druid_raw TO druid_raw;
