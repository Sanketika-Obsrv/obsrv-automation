const _ = require('lodash');
const env = process.env;
const path = require('path');

const { yamlToJSON } = require("../utils/yaml");

const pathToExporterConfig = path.join(__dirname, "exporter.yaml");
const exporterConfigs = yamlToJSON(pathToExporterConfig);

module.exports = {
    kafka: {
        brokers: _.get(env, 'KAFKA_BROKERS', 'b-2.dwxdevmsk.7g8ito.c4.kafka.ap-south-1.amazonaws.com:9092,b-1.dwxdevmsk.7g8ito.c4.kafka.ap-south-1.amazonaws.com:9092'),
        clientId: _.get(env, 'KAFKA_CLIENT_ID', 'kafka-message-exporter'),
        consumerGroupId: _.get(env, 'KAFKA_CONSUMER_GROUP_ID', 'kafka-message-exporter')
    },
    defaultLabels: { release: "monitoring" },
    exporterConfigs
}
