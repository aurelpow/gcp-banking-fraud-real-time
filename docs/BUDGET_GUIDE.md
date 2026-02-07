# Budget Testing Guide - Test Under $2

How to test the complete pipeline while keeping costs minimal.

---

## Expected Costs

### Budget Mode (Testing)
- **15-minute test**: ~$0.50
- **1-hour test**: ~$1.00
- **Full-day test**: ~$3-5

Most costs covered by GCP free tier!

### Standard Mode (Production)
- **Monthly cost**: ~$20-40 for continuous operation

---

## Budget Optimization Strategies

### 1. Reduce Scheduled Query Frequency

The scheduled queries are already configured for budget mode in `terraform/main.tf`:

```hcl
# Silver layer - Line ~121
schedule = "every 30 minutes"  # Instead of every 5 minutes

# Gold fraud metrics - Line ~177
schedule = "every 1 hours"  # Instead of every 10 minutes

# Gold merchant analytics - Line ~233
schedule = "every 1 hours"  # Instead of every 15 minutes
```

**Savings**: Reduces BigQuery processing costs by ~80%

---

### 2. Set Low Transaction Rate

Already configured in `.env.example`:

```env
TPS=1  # Only 1 transaction per second
```

**Savings**: Minimizes Pub/Sub message costs

---

### 3. Short Test Duration

**Recommendation for testing:**
- Run producer for **15-30 minutes** only
- Wait 30 minutes for Silver layer to populate
- Wait 1 hour for Gold layer to populate
- Destroy infrastructure immediately after

**Time Investment**: ~2 hours total
**Cost**: ~$0.50-1.00

---

## GCP Free Tier Benefits

Your test is mostly covered by these free quotas:

| Service | Free Tier | Your Usage |
|---------|-----------|------------|
| Pub/Sub | 10 GB/month | ~10 MB (1 hour test) |
| BigQuery Storage | 10 GB | < 1 MB |
| BigQuery Queries | 1 TB/month | < 1 GB |
| Cloud Logging | 50 GB/month | < 10 MB |

**Result**: Most costs are covered by free tier!

---

## Cost Breakdown (1-hour test)

| Component | Cost |
|-----------|------|
| Pub/Sub messages | ~$0.20 |
| BigQuery storage | Free (under 10 GB) |
| BigQuery queries | ~$0.30 |
| Scheduled queries | ~$0.40 |
| Cloud Logging | Free (under 50 GB) |
| **Total** | **~$0.90** |

---

## Testing Strategy

### For Portfolio Demo (Recommended)
```bash
# 1. Deploy infrastructure
cd terraform && terraform apply

# 2. Run producer for 30 minutes
cd ../producer && python producer.py
# Let it run, then Ctrl+C after 30 minutes

# 3. Wait 30 minutes for Silver layer ETL

# 4. Manually trigger Gold ETL (optional)
bq query --nouse_legacy_sql "INSERT INTO ..."

# 5. Take screenshots of:
#    - BigQuery tables with data
#    - Query results showing fraud detection
#    - Looker Studio dashboard

# 6. DESTROY IMMEDIATELY
cd terraform && terraform destroy
```

**Total time**: 2 hours
**Total cost**: ~$1.00
**Portfolio value**: Complete end-to-end demo

---

### For Full System Test
```bash
# Run for 2-3 hours to see multiple ETL cycles
# Cost: ~$2-3
```

---

---

## Stopping and Resuming the Pipeline

### Why Pause Instead of Destroy?

When you're testing or demonstrating the project, you might want to:
- Keep all your data for later analysis
- Preserve the infrastructure configuration
- Avoid re-running Terraform apply/destroy cycles
- Save costs during idle periods

**Pausing stops all expensive operations while keeping your data intact.**

---

### Stopping the Pipeline

To pause everything and avoid costs:

```bash
# 1. Stop the data generator (if running)
# Press Ctrl+C in the producer terminal

# 2. Disable all BigQuery scheduled queries
# First, list all scheduled queries to get their IDs
bq ls --transfer_config --project_id=YOUR_PROJECT_ID --transfer_location=us

# Disable each scheduled query (replace CONFIG_ID with actual IDs from above)
bq update --transfer_config --no_auto_scheduling projects/PROJECT_NUMBER/locations/us/transferConfigs/CONFIG_ID_1
bq update --transfer_config --no_auto_scheduling projects/PROJECT_NUMBER/locations/us/transferConfigs/CONFIG_ID_2
bq update --transfer_config --no_auto_scheduling projects/PROJECT_NUMBER/locations/us/transferConfigs/CONFIG_ID_3

# 3. Delete Pub/Sub subscriptions (keeps topics, deletes subscriptions only)
gcloud pubsub subscriptions delete bq-bronze-subscription --quiet
gcloud pubsub subscriptions delete dead-letter-subscription --quiet
```

**What gets stopped:**
- ❌ Data ingestion (Pub/Sub → BigQuery streaming)
- ❌ Scheduled query processing (Bronze → Silver → Gold)
- ✅ All data preserved in BigQuery tables
- ✅ Infrastructure definitions preserved in Terraform state

**Cost after stopping:**
- BigQuery storage: ~$0.02/GB/month (minimal for test data)
- Pub/Sub topics (no messages): $0.00
- Total: **< $0.10/month**

---

### Resuming the Pipeline

When you're ready to restart:

```bash
# 1. Recreate Pub/Sub subscriptions
cd terraform
terraform apply

# Note: Terraform will detect that subscriptions are missing and recreate them
# All other resources will remain unchanged

# 2. Re-enable scheduled queries
bq update --transfer_config --update_credentials projects/PROJECT_NUMBER/locations/us/transferConfigs/CONFIG_ID_1
bq update --transfer_config --update_credentials projects/PROJECT_NUMBER/locations/us/transferConfigs/CONFIG_ID_2
bq update --transfer_config --update_credentials projects/PROJECT_NUMBER/locations/us/transferConfigs/CONFIG_ID_3

# 3. Restart the data producer
cd ../producer
python producer.py
```

**Pipeline will resume exactly where it left off with all historical data intact.**

---

### Quick Stop Script (Copy-Paste)

Create a script to stop everything quickly:

```bash
# save as: scripts/stop-pipeline.sh
#!/bin/bash

echo "Stopping streaming pipeline..."

# Get project ID
PROJECT_ID=$(gcloud config get-value project)

# Stop scheduled queries
echo "Disabling scheduled queries..."
for config_id in $(bq ls --transfer_config --project_id=$PROJECT_ID --transfer_location=us --format=json | jq -r '.[].name'); do
  bq update --transfer_config --no_auto_scheduling $config_id
  echo "Disabled: $config_id"
done

# Delete subscriptions
echo "Deleting Pub/Sub subscriptions..."
gcloud pubsub subscriptions delete bq-bronze-subscription --quiet 2>/dev/null || echo "Already deleted"
gcloud pubsub subscriptions delete dead-letter-subscription --quiet 2>/dev/null || echo "Already deleted"

echo "✅ Pipeline stopped! Only minimal storage costs remain."
echo "💾 All data preserved in BigQuery tables"
```

---

### Quick Resume Script (Copy-Paste)

```bash
# save as: scripts/resume-pipeline.sh
#!/bin/bash

echo "Resuming streaming pipeline..."

# Get project ID
PROJECT_ID=$(gcloud config get-value project)

# Recreate subscriptions via Terraform
echo "Recreating Pub/Sub subscriptions..."
cd terraform
terraform apply -auto-approve

# Re-enable scheduled queries
echo "Re-enabling scheduled queries..."
for config_id in $(bq ls --transfer_config --project_id=$PROJECT_ID --transfer_location=us --format=json | jq -r '.[].name'); do
  bq update --transfer_config --update_credentials $config_id
  echo "Enabled: $config_id"
done

echo "✅ Pipeline resumed! Start the producer with: python producer/producer.py"
```

---

## Cost Monitoring

### Check Current Costs

```bash
# View billing in GCP Console
gcloud alpha billing accounts list
gcloud alpha billing projects describe PROJECT_ID

# Or visit: https://console.cloud.google.com/billing
```

### Set Up Budget Alert

1. Go to GCP Console → Billing → Budgets & alerts
2. Create budget: $5.00
3. Set alert at 50% ($2.50)
4. Add your email

**You'll be notified if costs exceed $2.50**

---

## Cleanup Checklist

To ensure you're not charged:

**Option 1: Pause (Recommended for active projects)**
- [ ] Stop the producer script (Ctrl+C)
- [ ] Disable scheduled queries (see "Stopping the Pipeline" above)
- [ ] Delete Pub/Sub subscriptions
- [ ] Keep all data and infrastructure for easy restart
- [ ] Cost: < $0.10/month for storage only

**Option 2: Full Cleanup (For completed projects)**
- [ ] Stop the producer script (Ctrl+C)
- [ ] Run `terraform destroy` in the terraform/ directory
- [ ] Verify all resources deleted:
  ```bash
  gcloud pubsub topics list
  bq ls fraud_detection  # Should error "not found"
  ```
- [ ] Check GCP Console for any remaining resources
- [ ] Review billing dashboard after 24 hours
- [ ] Cost: $0.00

---

## Additional Cost-Saving Tips

1. **Use existing GCP project**: No new project creation fees
2. **Same-day testing**: Deploy and destroy same day
3. **Off-peak hours**: Slightly lower BigQuery costs
4. **Single region**: Use `us-central1` (cheapest)
5. **Disable monitoring**: Already done (only dead letter queue)

---

## If Costs Exceed Budget

**Don't panic!** Even if you forget to destroy:

- **Worst case**: ~$1-2/day
- **30 days**: ~$30-60 (still reasonable)

**Immediate action**:
```bash
cd terraform
terraform destroy -auto-approve
```

---

## Questions?

- Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for common issues
- Review GCP Billing console for detailed cost breakdown
- All resources are in a single project for easy cleanup

**Remember**: Always run `terraform destroy` when done testing!
