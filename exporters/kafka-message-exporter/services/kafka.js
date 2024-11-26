const { Kafka, CompressionCodecs, CompressionTypes } = require('kafkajs')
const SnappyCodec = require("kafkajs-snappy")
const config = require('../config');
const _ = require('lodash');
const { processMessage } = require('../exporter');
var debug = require('debug')('kafka-message-exporter:kafka');

CompressionCodecs[CompressionTypes.Snappy] = SnappyCodec

const kafka = new Kafka({
    clientId: config.kafka.clientId,
    brokers: _.split(config.kafka.brokers, ',')
});

const runConsumer = async (payload) => {
    try {
        const { groupId, topics } = payload || {};
        const consumer = kafka.consumer({ groupId });
        await consumer.subscribe({ topics, fromBeginning: true });
        await consumer.run({
            eachMessage: processMessage
        })
    } catch (error) {
        debug("failed to start the kafka consumer");
        debug(err);
        process.exit(1)
    }
}

const getConsumerGroupName = () => config.kafka.consumerGroupId;

const createConsumers = async () => {
    const exporterConfigs = _.get(config, 'exporterConfigs', []);
    const topics = _.map(_.filter(exporterConfigs, ['enabled', true]), 'topic');
    debug("valid topic names", topics)
    await runConsumer({ groupId: getConsumerGroupName(), topics });
}

module.exports = { createConsumers }