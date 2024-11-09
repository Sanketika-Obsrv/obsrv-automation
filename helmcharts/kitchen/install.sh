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
    cmd="template"
else
    cmd="upgrade -i "
fi

case "$1" in
bootstrap)
    rm -rf bootstrapper
    cp -rf ../bootstrapper ./bootstrapper
    helm $cmd obsrv-bootstrap ./bootstrapper -n obsrv -f global-resource-values.yaml -f global-values.yaml -f images.yaml -f $cloud_file_name --create-namespace --debug
    ;;
coredb)
    rm -rf coredb
    cp -rf ../obsrv coredb
    cp -rf ../services/{kafka,postgresql,redis-denorm,redis-dedup,kong,druid-operator} coredb/charts/
    helm $cmd coredb ./coredb -n obsrv -f global-resource-values.yaml -f global-values.yaml -f images.yaml -f $cloud_file_name --debug
    ;;
migrations)
    rm -rf migrations
    cp -rf ../obsrv migrations
    cp -rf ../services/{postgresql-migration,cert-manager,kubernetes-reflector,grafana-configs} migrations/charts/

    helm $cmd migrations ./migrations -n obsrv -f global-resource-values.yaml -f global-values.yaml -f images.yaml -f $cloud_file_name --debug
    ;;
monitoring)
    rm -rf monitoring
    cp -rf ../obsrv monitoring
    cp -rf ../services/{promtail,loki,kube-prometheus-stack,kafka-message-exporter,alert-rules} monitoring/charts/
    helm $cmd monitoring ./monitoring -n obsrv -f global-resource-values.yaml -f global-values.yaml   -f images.yaml -f $cloud_file_name --debug
    ;;
coreinfra)
    rm -rf coreinfra
    cp -rf ../obsrv coreinfra
    cp -rf ../services/{druid-raw-cluster,flink,superset} coreinfra/charts/

    helm $cmd coreinfra ./coreinfra -n obsrv -f global-resource-values.yaml -f global-values.yaml -f images.yaml -f $cloud_file_name --debug
    ;;
obsrvapis)
    rm -rf obsrvapis
    cp -rf ../obsrv obsrvapis
    cp -rf ../services/{command-api,dataset-api,config-api} obsrvapis/charts/
    helm $cmd obsrvapis ./obsrvapis -n obsrv -f global-resource-values.yaml -f global-values.yaml -f images.yaml -f $cloud_file_name --debug
    ;;
hudi)
    rm -rf hudi
    cp -rf ../obsrv hudi
    cp -rf ../services/{hms,trino,lakehouse-connector} hudi/charts/
    helm $cmd hudi ./hudi -n obsrv -f global-resource-values.yaml -f global-values.yaml -f images.yaml -f $cloud_file_name --debug
    ;;
obsrvtools)
    rm -rf obsrvtools
    cp -rf ../obsrv obsrvtools
    cp -rf ../services/{web-console,submit-ingestion} obsrvtools/charts/
    helm $cmd obsrvtools ./obsrvtools -n obsrv -f global-resource-values.yaml -f global-values.yaml -f images.yaml -f $cloud_file_name --debug
    ;;
additional)
    rm -rf additional
    cp -rf ../obsrv additional
    cp -rf ../services/{spark,system-rules-ingestor,secor,druid-exporter,postgresql-exporter,postgresql-backup,kong-ingress-routes,letsencrypt-ssl,velero,volume-autoscaler} additional/charts/

    # copy cloud specific helm charts
    case $cloud_env in
    "aws")
        cp -rf ../services/s3-exporter additional/charts/
        ;;
    "azure")
        cp -rf ../services/azure-exporter additional/charts/
        ;;
    esac

    helm $cmd additional ./additional -n obsrv -f global-resource-values.yaml -f global-values.yaml -f images.yaml -f $cloud_file_name --debug
    ;;
all)
    bash $0 bootstrap
    bash $0 coredb
    bash $0 migrations
    bash $0 monitoring
    bash $0 coreinfra
    bash $0 obsrvapis
    bash $0 hudi
    bash $0 obsrvtools
    bash $0 additional

    ;;
reset)
    helm uninstall additional -n obsrv
    helm uninstall obsrvtools -n obsrv
    helm uninstall hudi -n obsrv
    helm uninstall obsrvapis -n obsrv
    helm uninstall coreinfra -n obsrv
    helm uninstall monitoring -n obsrv
    helm uninstall migrations -n obsrv
    helm uninstall coredb -n obsrv
    helm uninstall obsrv-bootstrap -n obsrv
    ;;
*)
    if [ ! -d "../services/$1" ]; then
        echo "Service $1 not found in ../services"
        exit 1
    fi
    cp -rf ../obsrv ./$1-ind
    cp -rf ../services/$1 ./$1-ind/charts/
    helm $cmd $1-ind ./$1-ind -n obsrv -f global-resource-values.yaml -f global-values.yaml -f images.yaml -f $cloud_file_name --debug
    rm -rf ./$1-ind
    ;;
esac

