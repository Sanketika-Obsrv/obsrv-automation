## Design

This program is designed to be eventually consistent, metrics exporter.

## What it does

Scrape a kafka topic for metrics of specific json format, and expose one endpoint for prometheus

## How to run

`docker run -e kafaka_host=172.19.0.2:9092 -e kafka_topic=dev.stats sanketikahub/kafka-message-exporter:v1`

## Json format

Example:
```
{
  "obsrv_meta": {
    "flags": {
      "Deduplication": "success",
      "ExtractorJob": "success",
      "DenormalizerJob": "success",
      "TransformerJob": "success",
      "EventValidation": "success"
    },
    "syncts": 1685613844979,
    "prevProcessingTime": 1685614164687,
    "error": {},
    "timespans": {
      "Deduplication": 2,
      "ExtractorJob": 319705,
      "total_processing_time": 319709,
      "DenormalizerJob": 0,
      "TransformerJob": 1,
      "EventValidation": 0
    }
  },
  "dataset": "sb-telemetry-benchmark"
}
```
