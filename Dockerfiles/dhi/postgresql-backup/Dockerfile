# DHI-hardened postgresql-backup (cronjob: pg_dump -> s3/azure/gcs).
# Base swapped python:alpine -> DHI python alpine-dev (has apk + pip + shell for
# installing the pg client + cloud CLIs). Same tool set + entrypoint as the
# original; only the base image is hardened. Runs as root (parity with the
# original python:alpine image) since it's a short-lived isolated backup job.

