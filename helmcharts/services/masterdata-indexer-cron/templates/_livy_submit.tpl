{{/*
Submits the MasterData Indexer job through Livy and polls until it finishes.
Shared by cronjob.yaml and cronjob-v2.yaml.

Usage:
  {{- include "masterdata-indexer-cron.livySubmitCommand" (dict
        "jarPath" .Values.dataproductsJar
        "namePrefix" "masterdata-indexer"
        "sparkHost" .Values.spark.host
        "sparkMaster" .Values.spark.master.host
        "driverJavaOpts" .Values.spark.driver.extraJavaOptions
        "executorJavaOpts" .Values.spark.executor.extraJavaOptions
        "roleArn" .Values.serviceAccountRoleArn
      ) | nindent 18 }}
*/}}
{{- define "masterdata-indexer-cron.livySubmitCommand" -}}
set -e
# Submits via Livy (like WFS) instead of kubectl exec + spark-submit, and polls for the
# real result instead of exiting as soon as Livy accepts the job.
kubectl wait --for=condition=Ready pod -n spark -l app.kubernetes.io/name=spark,app.kubernetes.io/component=master --timeout=300s
CURRENT_TIME=$(date +%Y-%m-%dT%H:%M)
# Unquoted delimiter is deliberate (needed for $CURRENT_TIME below) -- keep jarPath/javaOpts/roleArn
# free of $ and backticks, since they'd get shell-expanded into the JSON body instead of passed through.
JSON_BODY=$(cat <<JSON
{
    "file": {{ .jarPath | toJson }},
    "className": "org.sunbird.obsrv.dataproducts.MasterDataProcessorIndexer",
    "name": "{{ .namePrefix }}-$CURRENT_TIME",
    "conf": {
        "spark.master": {{ .sparkMaster | toJson }},
        "spark.driver.extraJavaOptions": {{ .driverJavaOpts | toJson }},
        "spark.executor.extraJavaOptions": {{ .executorJavaOpts | toJson }},
        "spark.driver.extraClassPath": "/data/conf",
        "spark.executor.extraClassPath": "/data/conf",
        "spark.hadoop.fs.s3a.impl": "org.apache.hadoop.fs.s3a.S3AFileSystem",
        "spark.hadoop.fs.s3a.aws.credentials.provider": "org.apache.hadoop.fs.s3a.auth.AssumedRoleCredentialProvider",
        "spark.hadoop.fs.s3a.assumed.role.credentials.provider": "com.amazonaws.auth.InstanceProfileCredentialsProvider",
        "spark.hadoop.fs.s3a.assumed.role.arn": {{ .roleArn | toJson }}
    }
}
JSON
)

# --fail-with-body prints Livy's error on failure instead of a bare non-zero exit. The explicit
# if/exit (rather than letting `set -e` kill the script here) is required so this line's own
# non-zero exit doesn't skip straight past printing $RESPONSE.
if ! RESPONSE=$(curl -sS --fail-with-body --max-time 30 --location "{{ .sparkHost }}" \
  --header "Content-Type: application/json" \
  --data "$JSON_BODY"); then
  echo "ERROR: Livy rejected the submission: $RESPONSE" >&2
  exit 1
fi
echo "$RESPONSE"
BATCH_ID=$(echo "$RESPONSE" | jq -r '.id')
if [ -z "$BATCH_ID" ] || [ "$BATCH_ID" = "null" ]; then
  echo "ERROR: Livy did not return a batch id" >&2
  exit 1
fi

echo "Submitted Livy batch $BATCH_ID, polling {{ .sparkHost }}$BATCH_ID/state for completion..."
while true; do
  # A failed status check just retries -- it shouldn't fail the run on its own.
  STATE=$(curl -sS --max-time 10 "{{ .sparkHost }}$BATCH_ID/state" 2>/dev/null | jq -r '.state // empty' || true)
  if [ -z "$STATE" ]; then
    echo "Could not read state for Livy batch $BATCH_ID, retrying..."
  else
    echo "Livy batch $BATCH_ID state: $STATE"
    case "$STATE" in
      success) exit 0 ;;
      dead|error|killed) exit 1 ;;
    esac
  fi
  sleep 15
done
{{- end -}}
