{{/*
Shell command that submits the MasterData Indexer job through Livy's /batches API and polls it to
a terminal state, so a failed indexer run fails this CronJob's Job too (not just the submission)
and concurrencyPolicy: Forbid stays meaningful. Shared by cronjob.yaml and cronjob-v2.yaml so the
submit/poll logic (and any future fix to it) only has to be written once.

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
# Submit through Livy's /batches API (like the WFS cron) instead of kubectl exec + spark-submit,
# so the job is tracked and visible in the Spark/Livy dashboard. curl returns as soon as Livy
# *accepts* the batch, not when the indexer finishes, so without polling this pod would exit 0
# within seconds regardless of outcome -- silencing failure alerting and making
# concurrencyPolicy: Forbid a no-op (it only blocks overlap while this pod stays alive).
kubectl wait --for=condition=Ready pod -n spark -l app.kubernetes.io/name=spark,app.kubernetes.io/component=master --timeout=300s
CURRENT_TIME=$(date +%Y-%m-%dT%H:%M)
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

# -sS --fail-with-body (not -sf): keeps quiet-on-success but still prints Livy's error body on a
# 4xx/5xx instead of just a bare non-zero exit, which is otherwise undiagnosable from Job logs.
# --max-time bounds just this submission call -- the poll loop below is what's allowed to run for
# as long as the indexer itself takes.
RESPONSE=$(curl -sS --fail-with-body --max-time 30 --location "{{ .sparkHost }}" \
  --header "Content-Type: application/json" \
  --data "$JSON_BODY")
echo "$RESPONSE"
BATCH_ID=$(echo "$RESPONSE" | jq -r '.id')
if [ -z "$BATCH_ID" ] || [ "$BATCH_ID" = "null" ]; then
  echo "ERROR: Livy did not return a batch id" >&2
  exit 1
fi

echo "Submitted Livy batch $BATCH_ID, polling {{ .sparkHost }}$BATCH_ID/state for completion..."
while true; do
  # A transient network/Livy blip here must not fail the whole run -- only Livy's own terminal
  # states (or giving up on the submission above) should. "|| true" plus the empty-state check
  # turns a failed/unparseable status check into "retry", not "job failed".
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
