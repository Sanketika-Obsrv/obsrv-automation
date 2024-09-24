package models

import (
	"sync"

	"github.com/segmentio/kafka-go"
)

type Config struct {
	Kafka map[string]map[string]string `yaml:"kafka"`
}

// Metrics structure
type Metrics struct {
	ObsrvMeta struct {
		LatencyTime int `json:"latency_time"`
		DataVersion int `json:"data_version"`
		Flags       struct {
			Deduplication   string `json:"Deduplication"`
			ExtractorJob    string `json:"ExtractorJob"`
			DenormalizerJob string `json:"DenormalizerJob"`
			TransformerJob  string `json:"TransformerJob"`
			EventValidation string `json:"EventValidation"`
		} `json:"flags"`
		Syncts              int64 `json:"syncts"`
		TotalProcessingTime int   `json:"total_processing_time"`
		PrevProcessingTime  int64 `json:"prevProcessingTime"`
		Error               struct {
		} `json:"error"`
		ProcessingTime      int   `json:"processing_time"`
		ProcessingStartTime int64 `json:"processingStartTime"`
		Timespans           struct {
			Deduplication   int `json:"Deduplication"`
			ExtractorJob    int `json:"ExtractorJob"`
			DenormalizerJob int `json:"DenormalizerJob"`
			TransformerJob  int `json:"TransformerJob"`
			EventValidation int `json:"EventValidation"`
		} `json:"timespans"`
	} `json:"obsrv_meta"`
	Dataset string `json:"dataset"`
}

type JobMetrics struct {
	Eid   string `json:"eid"`
	Ets   int64  `json:"ets"`
	Mid   string `json:"mid"`
	Actor struct {
		Id   string `json:"id"`
		Type string `json:"type"`
	} `json:"actor"`
	Context struct {
		Env   string `json:"env"`
		PData struct {
			Id      string `json:"id"`
			Pid     string `json:"pid"`
			Version string `json:"ver"`
		} `json:"pdata"`
	} `json:"context"`
	Object struct {
		Id      string `json:"id"`
		Type    string `json:"type"`
		Version string `json:"ver"`
	} `json:"object"`
	Edata struct {
		Metric map[string]interface{} `json:"metric"`
		Labels []struct {
			Key   string `json:"key"`
			Value string `json:"value"`
		} `json:"labels"`
	} `json:"edata"`
}

// Message format
type Metric struct {
	MetricLabel string
	Message   string
	Id        kafka.Message
	ClusterId int
}

// This is to get the last message served to prom endpoint.
type LastReadMessage struct {
	Mu sync.RWMutex
	// 	 map[partition]message
	Last map[int]kafka.Message
	// slice pointer of kafkaReaders
	ClusterId int
}
