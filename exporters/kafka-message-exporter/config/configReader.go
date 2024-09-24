package config

import (
	"kafka-message-exporter/models"
	"os"

	"gopkg.in/yaml.v2"
)

func ReadConfig(config_path string) models.Config {
	yamlFile, err := os.Open(config_path)
	if err != nil {
		panic(err)
	}
	defer yamlFile.Close()
	var config models.Config
	if yamlFile != nil {
		decoder := yaml.NewDecoder(yamlFile)
		if err := decoder.Decode(&config); err != nil {
			panic(err)
		}
	}

	return config
}
