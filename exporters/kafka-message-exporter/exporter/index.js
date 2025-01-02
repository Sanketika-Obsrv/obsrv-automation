const _ = require('lodash');
const path = require('path');
var debug = require('debug')('kafka-message-exporter:processMessage');

const { scrapModule } = require("../utils/fs");
const appConfig = require('../config');

const eventsHandler = scrapModule(__dirname, path.basename(__filename));

const processMessage = async ({ topic, partition, message, heartbeat, pause }) => {
    try {
        debug(`message received | topic - ${topic} | partition - ${partition}`);
        const config = _.find(appConfig.exporterConfigs, ['topic', topic]);
        if (!config) return;
        const handler = eventsHandler.get(_.get(config, 'name'))
        if (!handler) {
            debug("unsupported schema")
            return;
        }
        const event = message.value.toString();
        handler.process({ event: JSON.parse(event), config });
    } catch (error) {
        debug("error while processing this event", JSON.stringify({ topic, err: _.get(error, 'message'), message }));
    }
}

module.exports = { processMessage }