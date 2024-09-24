// Author : Kaliraja Ramasami <kaliraja.ramasamy@tarento.com>
// Author : Rajesh Rajendran <rjshrjdnrn@gmail.com>
// Author : Keshav Prasad <keshavprasadms@gmail.com>
package main

import (
	"context"
	"fmt"
	"kafka-message-exporter/config"
	"kafka-message-exporter/metricExporter"
	"kafka-message-exporter/models"
	"kafka-message-exporter/services"
	"log"
	"net"
	"net/http"
	"os"
	"strings"
	"time"

	kafka "github.com/segmentio/kafka-go"
	_ "github.com/segmentio/kafka-go/snappy"
)

var kafkaReaders []*kafka.Reader
var kafkaHosts []string
var kafkaTopic []string
var fileConfig models.Config
var counter = 0

var metricStore = metricExporter.NewMappingsStore()

var configKafkaReaders []map[string]string

// Channel to keep metrics till prometheus scrape that
var promMetricsChannel = make(chan metricExporter.Metric)

func health(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.Write([]byte("{\"Healthy\": true}"))
}

func serve(w http.ResponseWriter, r *http.Request) {
	fmt.Println("Serving Request")
	ctx := r.Context()
	var lastReadMessages []*models.LastReadMessage

	// Create a new context with cancellation
	ctx, cancel := context.WithCancel(ctx)
	defer cancel() // Ensure cancel() is called when the function returns

	// Reading topic
	for key, value := range kafkaReaders {
		lastReadMessage := models.LastReadMessage{}
		lastReadMessages = append(lastReadMessages, &lastReadMessage)
		go func(clusterId int, ctx context.Context, kafkaReader *kafka.Reader) {
			for {
				// Only fetching the message, not commiting them
				// It'll be commited once the transmission closes
				m, err := kafkaReader.FetchMessage(ctx)
				// Check if the context has been canceled
				select {
				case <-ctx.Done():
					fmt.Println("Context cancelled")
					return
				default:
				}

				if err != nil {
					fmt.Printf("err reading message: %v\n", err)
					break
				}
				fmt.Printf("topic: %q partition: %v offset: %v\n", m.Topic, m.Partition, m.Offset)
				go func(clusterId int, ctx context.Context, m kafka.Message) {
					for _, v := range configKafkaReaders {
						var schema string = ""
						var metricType interface{}
						if v["topic"] == m.Topic {
							schema = v["schema"]
							metricType, _ = metricStore.Get(schema)
							if err := metricExporter.MetricsCreation(clusterId, ctx, m, promMetricsChannel, schema, metricType); err != nil {
								fmt.Printf("errored out metrics creation; err:  %s\n", err)
								return
							}
						}
					}
				}(clusterId, ctx, m)
			}
		}(key, ctx, value)
	}
	for {
		select {
			case message := <-promMetricsChannel:
				counter = counter + 1
				fmt.Fprintf(w, "%s\n%s\n", fmt.Sprintf("# TYPE %s gauge", message.MetricLabel), message.Message)
				services.Store(lastReadMessages[message.ClusterId], message.Id, message.ClusterId)
			case <-ctx.Done():
				fmt.Println("Context cancelled")
				services.CommitMessage(&lastReadMessages, kafkaReaders)
				return
			case <-time.After(1 * time.Second):
				fmt.Println("Timeout")
				services.CommitMessage(&lastReadMessages, kafkaReaders)
				return
		}
	}
}

func main() {
	fileConfig = config.ReadConfig("config/config.yaml")

	for _, v := range fileConfig.Kafka {
		configKafkaReaders = append(configKafkaReaders, map[string]string{
			"host":   v["host"],
			"topic":  v["topic"],
			"schema": v["schema"],
		})
	}
	kafkaConsumerGroupName := os.Getenv("kafka_consumer_group_name")
	if kafkaConsumerGroupName == "" {
		kafkaConsumerGroupName = "prometheus-kafka-message-consumer"
	}
	if configKafkaReaders[0]["topic"] == "" || configKafkaReaders[0]["host"] == "" {
		log.Fatalf(`"kafka_topic or kafka_host environment variables not set."
For example,
	# export kafka_host=cluster1ip1:9092,cluster1ip2:9092;cluster2ip1:9092,cluster2ip2:9092
	# export kafka_topic=cluster1topic;cluster2topic
	# ',' seperated multiple kafka nodes in the cluster and
	# ';' seperated multiple kafka clusters
	export kafka_host=10.0.0.9:9092,10.0.0.10:9092;20.0.0.9:9092,20.0.0.10:9092
	export kafka_topic=sunbird.metrics.topic;myapp.metrics.topic`)
	}
	fmt.Printf("kafka_consumer_group_name: %s\n", kafkaConsumerGroupName)
	// Checking kafka topics are given for all kafka clusters
	if len(kafkaHosts) != len(kafkaTopic) {
		log.Fatal("You should give same number of kafka_topics as kafka_clusters")
	}
	// Checking kafka port and ip are accessible
	fmt.Println("Checking connection to Kafka")
	//Loop through configKafkaReaders and check if the connection is successful
	for _, v := range configKafkaReaders {
		for _, host := range strings.Split(v["host"], ",") {
			conn, err := net.DialTimeout("tcp", host, 8*time.Second)
			if err != nil {
				log.Fatalf("Connection error: %s", err)
			}
			fmt.Println("connection succeeded", host)
			conn.Close()
		}
	}
	fmt.Println("Kafka cluster is accessible")
	// Initializing kafka
	for k, v := range configKafkaReaders {
		kafkaReaders = append(kafkaReaders, kafka.NewReader(kafka.ReaderConfig{
			Brokers:          strings.Split(v["host"], ","),
			GroupID:          kafkaConsumerGroupName, // Consumer group ID
			Topic:            v["topic"],
			MinBytes:         1e3,  // 1KB
			MaxBytes:         10e6, // 10MB
			MaxWait:          200 * time.Millisecond,
			RebalanceTimeout: time.Second * 10,
		}))
		defer kafkaReaders[k].Close()
	}

	metricStore.Set("obsrv_meta", &metricExporter.Metrics{})
	metricStore.Set("telemetry", &metricExporter.JobMetrics{})
	http.HandleFunc("/metrics", serve)
	http.HandleFunc("/health", health)
	log.Fatal(http.ListenAndServe(":8000", nil))
}
