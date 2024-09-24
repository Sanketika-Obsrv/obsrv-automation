#!/bin/bash
while getopts ":t:" opt; do
  case $opt in
    t)
      tag=$OPTARG
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

if [ -z "$tag" ]; then
  echo "Missing required parameter: -t <tag> ##[specify the image tag for sanketikahub/flink-python:<tag>]"
  exit 1
fi

DOCKER_BUILDKIT=1 docker buildx build -t sanketikahub/flink-python:$tag --platform $DOCKER_DEFAULT_PLATFORM .