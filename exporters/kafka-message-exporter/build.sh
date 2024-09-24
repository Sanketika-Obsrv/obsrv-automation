# vim: set ts=4 sw=4 tw=0 et :
#!/bin/bash

CGO_ENABLED=0 GOARCH=amd64 GOOS=linux go build -o kafka-message-exporter main.go
docker build -f Dockerfile -t sanketikahub/kafka-message-exporter:v2 . --no-cache
