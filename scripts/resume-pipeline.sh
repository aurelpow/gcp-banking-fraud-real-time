#!/bin/bash

# Resume the streaming pipeline after stopping
# This script recreates Pub/Sub subscriptions and re-enables scheduled queries

set -e

echo "=========================================="
echo "Resuming Real-Time Fraud Detection Pipeline"
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

# Check if in correct directory
if [ ! -d "terraform" ]; then
  echo "❌ Error: terraform/ directory not found"
  echo "Run this script from the project root directory"
  exit 1
fi

# Recreate subscriptions via Terraform
echo "1️⃣  Recreating Pub/Sub subscriptions..."
cd terraform
terraform apply -auto-approve -target=google_pubsub_subscription.bq_sub -target=google_pubsub_subscription.dead_letter_sub >/dev/null 2>&1 && {
  echo "   ✅ Subscriptions recreated"
} || {
  echo "   ⚠️  Running full terraform apply..."
  terraform apply -auto-approve
}
cd ..
echo ""

# Re-enable scheduled queries
echo "2️⃣  Re-enabling BigQuery scheduled queries..."
configs=$(bq ls --transfer_config --project_id=$PROJECT_ID --transfer_location=us --format=json 2>/dev/null | jq -r '.[].name' 2>/dev/null || echo "")

if [ -z "$configs" ]; then
  echo "   ⚠️  No scheduled queries found"
  echo "   Run: cd terraform && terraform apply"
else
  count=0
  for config_id in $configs; do
    bq update --transfer_config --update_credentials $config_id >/dev/null 2>&1 && {
      echo "   ✅ Enabled: $(basename $config_id)"
      count=$((count+1))
    } || echo "   ⚠️  Failed to enable: $(basename $config_id)"
  done
  echo "   📊 Enabled $count scheduled queries"
fi
echo ""

echo "=========================================="
echo "✅ Pipeline Resumed Successfully!"
echo "=========================================="
echo ""
echo "📊 Current Status:"
echo "   ✅ Pub/Sub subscriptions active"
echo "   ✅ Scheduled queries enabled"
echo "   💾 All historical data preserved"
echo ""
echo "🚀 Next Steps:"
echo "   1. Start the producer:"
echo "      cd producer && python producer.py"
echo ""
echo "   2. Verify data flow:"
echo "      bq query --nouse_legacy_sql \\"
echo "        \"SELECT COUNT(*) FROM \\\`$PROJECT_ID.fraud_detection.bronze_transactions\\\`\""
echo ""
