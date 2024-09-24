### Description

This folder containes the deployment code for Obsrv.

### How to Create installation bundle chart

```
cp -rf services/{a,b,c} obsrv/charts/
```

### How to Install

```bash
helm upgrade -i obsrv-bootstrap ./bootstrapper -n obsrv -f global-values.yaml -f images.yaml -f global-cloud-values-gcp.yaml --debug --create-namespace
helm upgrade -i <release-name> ./obsrv -n obsrv -f global-values.yaml
```

### Environment specific installation

```bash
cp global-values.yaml dev-values.yaml
helm upgrade -i obsrv ./obsrv -n obsrv -f dev-values.yaml
```

## Folder structure

`services/`: Contains the helm chart for each service
`obsrv/`: Boiler plate umbrella helm chart to create final helm tar

```bash
> tree -L 2 ./obsrv
./obsrv/
├── Chart.lock
├── charts
│   ├── druid-raw-cluster
│   ├── flink
│   ├── grafana-configs
│   ├── kafka
│   ├── kafka-exporter
│   ├── ......
│   ├── kong
│   └── web-console
├── Chart.yaml
└── values.yaml
```
