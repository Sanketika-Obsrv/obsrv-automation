const _ = require('lodash');
const { getOrCreateMetric, getLabelsMapping } = require('../services/prometheus');

module.exports = {
    name: "spark-stats",
    process: (payload) => {
        const { event = {}, config } = payload;
        const inputPrefix = _.get(config, 'prefix');
        const prefixPath = _.get(config, 'prefixPath')
        const prefix = inputPrefix || (prefixPath ? _.get(event, prefixPath, '') : '');
        const { edata = {} } = event;
        const { labels = [], metric = {} } = edata;
        _.forEach(metric, process({ labels, event, prefix }))
    }
}

const process = payload => (value, key) => {
    const { labels, prefix } = payload;
    const metricKey = prefix ? `${prefix}_${key}` : key;
    const metricLabels = getLabelsMapping(labels);
    const metric = getOrCreateMetric(metricKey, metricLabels)
    metric.labels(metricLabels).set(value)
}