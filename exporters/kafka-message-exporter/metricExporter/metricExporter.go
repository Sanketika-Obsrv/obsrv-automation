package metricExporter

import (
	"context"
	"encoding/json"
	"fmt"
	"kafka-message-exporter/models"
	"kafka-message-exporter/utils"
	"strings"

	"github.com/segmentio/kafka-go"
)

type JobMetrics struct {
	models.JobMetrics
}

type Metrics struct {
	models.Metrics
}

type Metric struct {
	models.Metric
}

type MetricType struct {
	ObsrvMeta  Metrics
	SparkStats JobMetrics
}

type MappingsStore struct {
	Mappings map[string]interface{}
}

func NewMappingsStore() *MappingsStore {
	return &MappingsStore{
		Mappings: make(map[string]interface{}),
	}
}

func (ms *MappingsStore) Get(key string) (interface{}, bool) {
	val, ok := ms.Mappings[key]
	return val, ok
}

func (ms *MappingsStore) Set(key string, value interface{}) {
	ms.Mappings[key] = value
}

func MetricsCreation(clusterId int, ctx context.Context, m kafka.Message, promMetricsChannel chan Metric, schema string, metrics interface{}) error {
	select {
	case <-ctx.Done():
		return ctx.Err()
	default:
		switch metrics.(type) {
		case *Metrics:
			structure := Metrics{}
			if err := json.Unmarshal(m.Value, &structure); err != nil {
				fmt.Printf("Unmarshal error: %q data: %q\n", err, string(m.Value))
				return err
			}
			structure.PushMetrics(clusterId, ctx, &m, promMetricsChannel)
		case *JobMetrics:
			structure := JobMetrics{}
			if err := json.Unmarshal(m.Value, &structure); err != nil {
				fmt.Printf("Unmarshal error: %q data: %q\n", err, string(m.Value))
				return err
			}
			structure.PushMetrics(clusterId, ctx, &m, promMetricsChannel)
		default:
			fmt.Printf("Schema not found\n")
		}
		return nil
	}
}

func (metrics *JobMetrics) PushMetrics(clusterId int, ctx context.Context, metricData *kafka.Message, promMetricsChannel chan Metric) error {
	select {
	case <-ctx.Done():
		return ctx.Err()
	default:
		for metricKey, metricValue := range metrics.Edata.Metric {
			var label string = ""
			for i := 0; i < len(metrics.Edata.Labels); i++ {
				label += fmt.Sprintf("%s=\"%s\",", metrics.Edata.Labels[i].Key, metrics.Edata.Labels[i].Value)
			}
			// Add mid in the label to differentiate between metrics for counts to be not merged
			label += fmt.Sprintf("%s=\"%s\",", "mid", metrics.Mid)
			var metricLabel = strings.ToLower(metrics.Actor.Id + "_" + metricKey)
			var metricStruct = Metric{}
			metricStruct.MetricLabel = metricLabel
			metricStruct.Message = fmt.Sprintf("%s{%s} %v %d", metricLabel, strings.TrimRight(label, ","), metricValue, metrics.Ets)
			metricStruct.Id = *metricData
			metricStruct.ClusterId = clusterId
			promMetricsChannel <- metricStruct
		}
		return nil
	}
}

// TODO: Add unique label to differentiate between metrics for counts to be not merged
func (metrics *Metrics) PushMetrics(clusterId int, ctx context.Context, metricData *kafka.Message, promMetricsChannel chan Metric) error {
	// Check if the context has been canceled
	select {
	case <-ctx.Done():
		return ctx.Err()
	default:
		// Creating dictionary of labels
		label := fmt.Sprintf("dataset=%q, metric=%q, stage=%q, job=%q", metrics.Dataset, "processing_time", utils.MetricsNameValidator("Deduplication"), "kafka-message-exporter")
		// Generating metrics
		metricStruct := Metric{}
		metricStruct.MetricLabel = "obsrv_pipeline_metrics"
		metricStruct.Message = fmt.Sprintf("%s{%s} %d %d",
			"obsrv_pipeline_metrics",
			strings.TrimRight(label, ","), metrics.ObsrvMeta.Timespans.Deduplication, metrics.ObsrvMeta.Syncts)
		metricStruct.Id = *metricData
		metricStruct.ClusterId = clusterId
		promMetricsChannel <- metricStruct

		label = fmt.Sprintf("dataset=%q, metric=%q, stage=%q, job=%q", metrics.Dataset, "processing_time", utils.MetricsNameValidator("ExtractorJob"), "kafka-message-exporter")
		metricStruct = Metric{}
		metricStruct.MetricLabel = "obsrv_pipeline_metrics"
		metricStruct.Message = fmt.Sprintf("%s{%s} %d %d",
			"obsrv_pipeline_metrics",
			strings.TrimRight(label, ","), metrics.ObsrvMeta.Timespans.ExtractorJob, metrics.ObsrvMeta.Syncts)
		metricStruct.Id = *metricData
		metricStruct.ClusterId = clusterId
		promMetricsChannel <- metricStruct

		label = fmt.Sprintf("dataset=%q, metric=%q, stage=%q, job=%q", metrics.Dataset, "processing_time", utils.MetricsNameValidator("DenormalizerJob"), "kafka-message-exporter")
		metricStruct = Metric{}
		metricStruct.MetricLabel = "obsrv_pipeline_metrics"
		metricStruct.Message = fmt.Sprintf("%s{%s} %d %d",
			"obsrv_pipeline_metrics",
			strings.TrimRight(label, ","), metrics.ObsrvMeta.Timespans.DenormalizerJob, metrics.ObsrvMeta.Syncts)
		metricStruct.Id = *metricData
		metricStruct.ClusterId = clusterId
		promMetricsChannel <- metricStruct

		label = fmt.Sprintf("dataset=%q, metric=%q, stage=%q, job=%q", metrics.Dataset, "processing_time", utils.MetricsNameValidator("TransformerJob"), "kafka-message-exporter")
		metricStruct = Metric{}
		metricStruct.MetricLabel = "obsrv_pipeline_metrics"
		metricStruct.Message = fmt.Sprintf("%s{%s} %d %d",
			"obsrv_pipeline_metrics",
			strings.TrimRight(label, ","), metrics.ObsrvMeta.Timespans.TransformerJob, metrics.ObsrvMeta.Syncts)
		metricStruct.Id = *metricData
		metricStruct.ClusterId = clusterId
		promMetricsChannel <- metricStruct

		label = fmt.Sprintf("dataset=%q, metric=%q, stage=%q, job=%q", metrics.Dataset, "processing_time", utils.MetricsNameValidator("EventValidation"), "kafka-message-exporter")
		metricStruct = Metric{}
		metricStruct.MetricLabel = "obsrv_pipeline_metrics"
		metricStruct.Message = fmt.Sprintf("%s{%s} %d %d",
			"obsrv_pipeline_metrics",
			strings.TrimRight(label, ","), metrics.ObsrvMeta.Timespans.EventValidation, metrics.ObsrvMeta.Syncts)
		metricStruct.Id = *metricData
		metricStruct.ClusterId = clusterId
		promMetricsChannel <- metricStruct

		label = fmt.Sprintf("dataset=%q, metric=%q, stage=%q, job=%q", metrics.Dataset, "total_processing_time", "all", "kafka-message-exporter")
		metricStruct = Metric{}
		metricStruct.MetricLabel = "obsrv_pipeline_metrics"
		metricStruct.Message = fmt.Sprintf("%s{%s} %d %d",
			"obsrv_pipeline_metrics",
			strings.TrimRight(label, ","), metrics.ObsrvMeta.TotalProcessingTime, metrics.ObsrvMeta.Syncts)
		metricStruct.Id = *metricData
		metricStruct.ClusterId = clusterId
		promMetricsChannel <- metricStruct

		label = fmt.Sprintf("dataset=%q, metric=%q, stage=%q, job=%q", metrics.Dataset, "processing_time", "all", "kafka-message-exporter")
		metricStruct = Metric{}
		metricStruct.MetricLabel = "obsrv_pipeline_metrics"
		metricStruct.Message = fmt.Sprintf("%s{%s} %d %d",
			"obsrv_pipeline_metrics",
			strings.TrimRight(label, ","), metrics.ObsrvMeta.ProcessingTime, metrics.ObsrvMeta.Syncts)
		metricStruct.Id = *metricData
		metricStruct.ClusterId = clusterId
		promMetricsChannel <- metricStruct

		label = fmt.Sprintf("dataset=%q, metric=%q, stage=%q, job=%q", metrics.Dataset, "latency_time", "all", "kafka-message-exporter")
		metricStruct = Metric{}
		metricStruct.MetricLabel = "obsrv_pipeline_metrics"
		metricStruct.Message = fmt.Sprintf("%s{%s} %d %d",
			"obsrv_pipeline_metrics",
			strings.TrimRight(label, ","), metrics.ObsrvMeta.LatencyTime, metrics.ObsrvMeta.Syncts)
		metricStruct.Id = *metricData
		metricStruct.ClusterId = clusterId
		promMetricsChannel <- metricStruct

		return nil
	}
}
