const _ = require('lodash');
const { getOrCreateMetric } = require('../services/prometheus');
const { renameKey } = require('../utils/common');

module.exports = {
    name: "wfs",
    process: (payload) => {
        const { event = {}, config } = payload;
        const inputPrefix = _.get(config, 'prefix');
        const prefixPath = _.get(config, 'prefixPath')
        const prefix = inputPrefix || (prefixPath ? _.get(event, prefixPath, '') : '');
        const { dimensions = [], metrics = [] } = event;
        _.forEach(metrics, process({ dimensions, prefix }));
    }
}

const getLabelsMapping = (labels) => {
    return _.reduce(labels, (mapping, current) => {
        const { id, value } = current;
        const key = renameKey(id);
        mapping[key] = value;
        return mapping;
    }, {})
}

const process = payload => metricMetadata => {
    const { id, value } = metricMetadata;
    const { dimensions, prefix } = payload;
    const metricKey = prefix ? `${prefix}_${id}` : id;
    const metricLabels = getLabelsMapping(dimensions);
    const metric = getOrCreateMetric(metricKey, metricLabels)
    metric.labels(metricLabels).set(value)
}