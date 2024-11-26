const client = require('prom-client');
const config = require('../config')
const _ = require('lodash');
const { renameKey } = require('../utils/common');

const register = new client.Registry();

client.collectDefaultMetrics({ register });
register.setDefaultLabels(config.defaultLabels);

const metrics = {};

const registerMetric = (metric) => {
    register.registerMetric(metric);
}

const createGuageMetric = payload => {
    const { name, help = "", labelNames = [], ...rest } = payload;
    return new client.Gauge({ name, help: name, labelNames, ...rest })
}

const getMetric = key => {
    return _.get(metrics, key);
}

// Function to get or create a metric dynamically
const getOrCreateMetric = (key, labels) => {
    const metricName = renameKey(key)
    let metric = getMetric(metricName);
    if (!metric) {
        metric = createGuageMetric({ name: metricName, labelNames: Object.keys(labels) });
        registerMetric(metric);
        metrics[metricName] = metric;
    }
    return metric;
};

// Transforms list of metric labels array {key: string, value: string}[] into a map {key1: value1, key2: value2}
const getLabelsMapping = (labels) => {
    return _.reduce(labels, (mapping, current) => {
        const { key, value } = current;
        mapping[key] = value;
        return mapping;
    }, {})
}

module.exports = { register, getLabelsMapping, getOrCreateMetric };