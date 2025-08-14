#!/usr/bin/bash
set -x

cloud_file_name="cloud_values.yaml"

# Set the cloud-specific values file
case $cloud_env in
    "aws")
        cp -rf ../global-cloud-values-aws.yaml ./$cloud_file_name
        ;;
    "gcp")
        cp -rf ../global-cloud-values-gcp.yaml ./$cloud_file_name
        ;;
    "azure")
        cp -rf ../global-cloud-values-azure.yaml ./$cloud_file_name
        ;;
    *)
        cp -rf ../local-datacenter.yaml ./$cloud_file_name
        ;;
esac

cp -rf ../{global-values.yaml,global-resource-values.yaml,images.yaml} ./

if [ "$2" == "template" ]; then
    cmd="template ${@: 3}"
else
    cmd="upgrade -i ${@: 2}"
fi

case "$1" in
bootstrap)
    cp -rf ../bootstrapper ./bootstrapper
    helm $cmd obsrv-bootstrap ./bootstrapper -n obsrv -f global-resource-values.yaml -f global-values.yaml -f images.yaml -f $cloud_file_name --create-namespace
    rm -rf bootstrapper
    ;;
prerequisites)
    if [ -z "$cloud_env" ]; then
        cp -rf ../obsrv prerequisites
        cp -rf ../services/minio prerequisites/charts/
        helm $cmd prerequisites ./prerequisites -n obsrv -f global-resource-values.yaml -f global-values.yaml -f images.yaml -f $cloud_file_name
        rm -rf prerequisites
    fi
    ;;
coredb)
    cp -rf ../obsrv coredb
    cp -rf ../services/{kafka,postgresql,kong,druid-operator,valkey-dedup,valkey-denorm} coredb/charts/

    ssl_enabled=$(cat $cloud_file_name | grep 'ssl_enabled:' | awk '{ print $3}')
    if [ "$ssl_enabled" == "true" ]; then
        cp -rf ../services/cert-manager coredb/charts/
    fi

    helm $cmd coredb ./coredb -n obsrv -f global-resource-values.yaml -f global-values.yaml -f images.yaml -f $cloud_file_name
    rm -rf coredb
    ;;
kafka40)
    cp -rf ../obsrv kafka40
    cp -rf ../services/kafka40 kafka40/charts/

    ssl_enabled=$(cat $cloud_file_name | grep 'ssl_enabled:' | awk '{ print $3}')
    if [ "$ssl_enabled" == "true" ]; then
        cp -rf ../services/cert-manager kafka40/charts/
    fi

    helm $cmd kafka40 ./kafka40 -n obsrv -f global-resource-values.yaml -f global-values.yaml -f images.yaml -f $cloud_file_name 
    rm -rf kafka40
    ;;
migrations)
    cp -rf ../obsrv migrations
    cp -rf ../services/{postgresql-migration,kubernetes-reflector,grafana-configs,letsencrypt-ssl} migrations/charts/

    helm $cmd migrations ./migrations -n obsrv -f global-resource-values.yaml -f global-values.yaml -f images.yaml -f $cloud_file_name
    rm -rf migrations
    ;;
monitoring)
    cp -rf ../obsrv monitoring
    cp -rf ../services/{promtail,loki,kube-prometheus-stack,prometheus-pushgateway,kafka-message-exporter,kafka-exporter,alert-rules} monitoring/charts/

    if [ -z "$cloud_env" ]; then
        rm -rf monitoring/charts/loki/charts/minio
    fi
    
    helm $cmd monitoring ./monitoring -n obsrv -f global-resource-values.yaml -f global-values.yaml  -f images.yaml -f $cloud_file_name
    rm -rf monitoring
    ;;
coreinfra)
    cp -rf ../obsrv coreinfra
    cp -rf ../services/{druid-raw-cluster,flink,superset} coreinfra/charts/

    helm $cmd coreinfra ./coreinfra -n obsrv -f global-resource-values.yaml -f global-values.yaml -f images.yaml -f $cloud_file_name
    rm -rf coreinfra
    ;;
obsrvapis)
    cp -rf ../obsrv obsrvapis
    cp -rf ../services/{command-api,dataset-api} obsrvapis/charts/
    helm $cmd obsrvapis ./obsrvapis -n obsrv -f global-resource-values.yaml -f global-values.yaml  -f images.yaml -f $cloud_file_name
    rm -rf obsrvapis
    ;;
hudi)
    cp -rf ../obsrv hudi
    cp -rf ../services/{hms,trino,lakehouse-connector} hudi/charts/
    helm $cmd hudi ./hudi -n obsrv -f global-resource-values.yaml -f global-values.yaml -f images.yaml -f $cloud_file_name
    rm -rf hudi
    ;;
otel)
    cp -rf ../obsrv opentelemetry-collector
    cp -rf ../services/opentelemetry-collector opentelemetry-collector/charts/
    helm $cmd opentelemetry-collector ./opentelemetry-collector -n obsrv -f global-resource-values.yaml -f global-values.yaml -f images.yaml -f $cloud_file_name
    rm -rf opentelemetry-collector
    ;;
oauth)
    cp -rf ../obsrv oauth
    cp -rf ../services/keycloak oauth/charts/
    helm $cmd oauth ./oauth -n obsrv -f global-resource-values.yaml -f global-values.yaml -f images.yaml -f $cloud_file_name
    rm -rf oauth
    ;;
obsrvtools)
    cp -rf ../obsrv obsrvtools
    cp -rf ../services/{web-console,submit-ingestion} obsrvtools/charts/
    helm $cmd obsrvtools ./obsrvtools -n obsrv -f global-resource-values.yaml -f global-values.yaml -f images.yaml -f $cloud_file_name
    rm -rf obsrvtools
    ;;
additional)
    cp -rf ../obsrv additional
    cp -rf ../services/{spark,system-rules-ingestor,secor,druid-exporter,postgresql-exporter,postgresql-backup,kong-ingress-routes,velero,volume-autoscaler,masterdata-indexer-cron} additional/charts/
    # copy cloud specific helm charts
    case $cloud_env in
    "aws")
        cp -rf ../services/s3-exporter additional/charts/
        ;;
    "azure")
        cp -rf ../services/azure-exporter additional/charts/
        ;;
    "gcp")
        echo "no additional charts for gcp"
        ;;
    *)
        cp -rf ../services/s3-exporter additional/charts/
        ;;
    esac

    helm $cmd additional ./additional -n obsrv -f global-resource-values.yaml -f global-values.yaml -f images.yaml -f $cloud_file_name
    rm -rf additional
    ;;
core-setup)
    bash $0 bootstrap ${@: 2}
    bash $0 prerequisites ${@: 2}
    bash $0 coredb ${@: 2}
    bash $0 kafka40 ${@: 2}
    ;;
all)
    bash $0 migrations ${@: 2}
    bash $0 monitoring ${@: 2}
    bash $0 oauth ${@: 2}
    bash $0 coreinfra ${@: 2}
    bash $0 obsrvapis ${@: 2}
    # We are not installing these for now.
    # bash $0 hudi ${@: 2}
    # bash $0 otel ${@: 2}
    bash $0 obsrvtools ${@: 2}
    bash $0 additional ${@: 2}

    ;;

register_connectors)
    echo "Running connector registration script..."
    chmod +x ../../connectors/register.sh
    ../../connectors/register.sh
    ;;

 # Warning: The reset will uninstall all the helm charts in obsrv namespace and enable it only for development purposes.
# reset)
#     echo "Uninstalling all helm charts in obsrv namespace..."
#     helm uninstall additional -n obsrv
#     helm uninstall obsrvtools -n obsrv
#     helm uninstall otel -n obsrv
#     helm uninstall hudi -n obsrv
#     helm uninstall obsrvapis -n obsrv
#     helm uninstall coreinfra -n obsrv
#     helm uninstall oauth -n obsrv
#     helm uninstall monitoring -n obsrv
#     helm uninstall migrations -n obsrv
#     helm uninstall kafka40 -n obsrv
#     helm uninstall coredb -n obsrv
#     helm uninstall kafka40 -n obsrv
#     helm uninstall prerequisites -n obsrv
#     helm uninstall obsrv-bootstrap -n obsrv
#     ;;
*)
    if [ ! -d "../services/$1" ]; then
        echo "Service $1 not found in ../services"
        exit 1
    fi
    cp -rf ../obsrv ./$1-ind
    cp -rf ../services/$1 ./$1-ind/charts/
    helm $cmd $1-ind ./$1-ind -n obsrv -f global-resource-values.yaml -f global-values.yaml -f images.yaml -f $cloud_file_name
    rm -rf ./$1-ind
    ;;
esac


rm -rf $cloud_file_name
rm -rf {global-values.yaml,global-resource-values.yaml,images.yaml}