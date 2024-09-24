#!/bin/bash
set -euox pipefail
# apt update && apt install -y postgresql-client
while read -r line
do
  db=$(echo $line | cut -d '-' -f2-)
  # Kubernetes wont allow _ in configmap names
  # This is to make sure existing clusters are comptaible
  # Future dbs should use - instead of _
  if [[ "$db" == "druid-raw" ]]
  then
    db="druid_raw"
  fi
  # Creation of Database is moved to postgres.primary.initdb.scripts
  # echo "Creating database \"$db\" if not exists";
  # echo ""
  # echo "SELECT 'CREATE DATABASE $db' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$db')\gexec" | psql -U postgres -h postgresql-hl
  # echo ""
  echo "Running fly migration for \"$db\"";
  echo ""
  flyway migrate -url=jdbc:postgresql://postgresql-hl:5432/$db -locations="filesystem:/migrations/$line"
  echo ""
done <<< $(ls /migrations | sort -n)