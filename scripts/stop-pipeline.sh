#!/bin/bash

# Stop the streaming pipeline to save costs
# This script disables scheduled queries and deletes Pub/Sub subscriptions
# All data is preserved in BigQuery tables

set -e

echo "=========================================="
echo "Stopping Real-Time Fraud Detection Pipeline"
echo "=========================================="
echo ""

# Get project ID
PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
if [ -z "$PROJECT_ID" ]; then
  echo "❌ Error: No GCP project configured"
  echo "Run: gcloud config set project YOUR_PROJECT_ID"
  exit 1
fi

echo "📋 Project: $PROJECT_ID"
echo ""

# Stop scheduled queries
echo "1️⃣  Disabling BigQuery scheduled queries..."
configs=$(bq ls --transfer_config --project_id=$PROJECT_ID --transfer_location=us --format=json 2>/dev/null | jq -r '.[].name' 2>/dev/null || echo "")

if [ -z "$configs" ]; then
  echo "   ℹ️  No scheduled queries found"
else
  count=0
  for config_id in $configs; do
    bq update --transfer_config --no_auto_scheduling $config_id >/dev/null 2>&1 && {
      echo "   ✅ Disabled: $(basename $config_id)"
      count=$((count+1))
    } || echo "   ⚠️  Failed to disable: $(basename $config_id)"
  done
  echo "   📊 Disabled $count scheduled queries"
fi
echo ""

# Delete subscriptions
echo "2️⃣  Deleting Pub/Sub subscriptions..."
sub_count=0

gcloud pubsub subscriptions delete bq-bronze-subscription --quiet 2>/dev/null && {
  echo "   ✅ Deleted: bq-bronze-subscription"
  sub_count=$((sub_count+1))
} || echo "   ℹ️  bq-bronze-subscription already deleted"

gcloud pubsub subscriptions delete dead-letter-subscription --quiet 2>/dev/null && {
  echo "   ✅ Deleted: dead-letter-subscription"
  sub_count=$((sub_count+1))
} || echo "   ℹ️  dead-letter-subscription already deleted"

echo "   📊 Deleted $sub_count subscriptions"
echo ""

# Check producer
echo "3️⃣  Checking for running producer..."
if pgrep -f "producer.py" >/dev/null 2>&1; then
  echo "   ⚠️  Producer still running! Stop it with Ctrl+C or:"
  echo "      pkill -f producer.py"
else
  echo "   ✅ No producer process running"
fi
echo ""

echo "=========================================="
echo "✅ Pipeline Stopped Successfully!"
echo "=========================================="
echo ""
echo "💾 All data preserved in BigQuery tables:"
echo "   - bronze_transactions"
echo "   - silver_transactions"
echo "   - gold_fraud_metrics"
echo "   - gold_merchant_analytics"
echo ""
echo "💰 Remaining costs: ~$0.02-0.10/month (storage only)"
echo ""
echo "🔄 To resume: Run ./scripts/resume-pipeline.sh"
echo "🗑️  To fully delete: cd terraform && terraform destroy"
echo ""
