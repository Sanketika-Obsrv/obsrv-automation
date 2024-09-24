#!/usr/bin/env bash

set -euxo pipefail

generate_database_config(){
  cat << XML
<property>
  <name>javax.jdo.option.ConnectionDriverName</name>
  <value>${DATABASE_DRIVER}</value>
</property>
<property>
  <name>javax.jdo.option.ConnectionURL</name>
  <value>jdbc:${DATABASE_TYPE_JDBC}://${DATABASE_HOST}:${DATABASE_PORT}/${DATABASE_DB}</value>
</property>
<property>
  <name>javax.jdo.option.ConnectionUserName</name>
  <value>${DATABASE_USER}</value>
</property>
<property>
  <name>javax.jdo.option.ConnectionPassword</name>
  <value>${DATABASE_PASSWORD}</value>
</property>
XML
}

generate_hive_site_config(){
  database_config=$(generate_database_config)
  cat << XML > "$1"
<configuration>
$database_config
</configuration>
XML
}

generate_metastore_site_config(){
  database_config=$(generate_database_config)
  cat << XML > "$1"
<configuration>
  <property>
    <name>metastore.task.threads.always</name>
    <value>org.apache.hadoop.hive.metastore.events.EventCleanerTask</value>
  </property>
  <property>
    <name>metastore.expression.proxy</name>
    <value>org.apache.hadoop.hive.metastore.DefaultPartitionExpressionProxy</value>
  </property>
  $database_config
  <property>
    <name>metastore.warehouse.dir</name>
    <value>${WAREHOUSE_DIR}</value>
  </property>
  <property>
    <name>metastore.thrift.port</name>
    <value>${THRIFT_PORT}</value>
  </property>
   <property>
    <name>metastore.disallow.incompatible.col.type.changes</name>
    <value>false</value>
  </property>
</configuration>
XML
}

run_migrations(){
  if /opt/hive-metastore/bin/schematool -dbType "$DATABASE_TYPE" -validate | grep 'Done with metastore validation' | grep '[SUCCESS]'; then
    echo 'Database OK'
    return 0
  else
    # TODO: how to apply new version migrations or repair validation issues
    /opt/hive-metastore/bin/schematool --verbose -dbType "$DATABASE_TYPE" -initSchema
  fi
}

# configure & run schematool
generate_hive_site_config /opt/hadoop/etc/hadoop/hive-site.xml
run_migrations

# configure & start metastore (in foreground)
generate_metastore_site_config /opt/hive-metastore/conf/metastore-site.xml
# generate_core_site_config /opt/hadoop/etc/hadoop/core-site.xml
/opt/hive-metastore/bin/start-metastore
