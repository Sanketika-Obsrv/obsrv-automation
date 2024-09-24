package services

import (
	"context"
	"errors"
	"fmt"
	"kafka-message-exporter/models"

	"github.com/segmentio/kafka-go"
)

func CommitMessage(lastReadMessages *[]*models.LastReadMessage, kafkaReaders []*kafka.Reader) error {
	fmt.Println("number of clusters: ", len(*lastReadMessages))
	for _, lrm := range *lastReadMessages {
		messages, clusterId := Get(lrm)
		fmt.Println("cluster: ", clusterId)
		for k, message := range messages {
			if message.Offset <= 0 {
				fmt.Println("Not committing anything", clusterId)
				return errors.New("offset is not > 0 for cluster " + string(clusterId))
			}
			fmt.Printf("Commiting message partition %d offset %d cluster %d\n", k, message.Offset, clusterId)
			if err := kafkaReaders[clusterId].CommitMessages(context.Background(), message); err != nil {
				return err
			}
		}
	}
	return nil
}

// Adding message
// Only the latest
func Store(lrm *models.LastReadMessage, message kafka.Message, clusterId int) error {
	lrm.Mu.Lock()
	defer lrm.Mu.Unlock()
	// Initializing map if nil
	if lrm.Last == nil {
		lrm.Last = make(map[int]kafka.Message)
	}
	if _, ok := lrm.Last[message.Partition]; ok {
		// Updating only if the offset is greater
		if lrm.Last[message.Partition].Offset < message.Offset {
			lrm.Last[message.Partition] = message
			lrm.ClusterId = clusterId
		}
		return fmt.Errorf("lower offset(%d) than the latest(%d)", message.Offset, lrm.Last[message.Partition].Offset)
	} else {
		lrm.Last[message.Partition] = message
		lrm.ClusterId = clusterId
	}
	return nil
}

// Return the last message read
func Get(lrm *models.LastReadMessage) (map[int]kafka.Message, int) {
	lrm.Mu.RLock()
	defer lrm.Mu.RUnlock()
	return lrm.Last, lrm.ClusterId
}
