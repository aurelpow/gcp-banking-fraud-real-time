# Troubleshooting Guide

Common issues and solutions for the GCP Real-Time Streaming Pipeline.

---

## Quick Diagnostics

```bash
# Check Terraform state
cd terraform && terraform show

# Check BigQuery tables
bq ls fraud_detection

# Check Pub/Sub subscriptions
gcloud pubsub subscriptions list

# Check scheduled queries
bq ls --transfer_config --transfer_location=US

# Check Cloud Logging
gcloud logging read "resource.type=bigquery_resource" --limit 10
```

---

## Common Issues

### 1. API Not Enabled

**Error:**
```
Error 403: [API] has not been used in project [PROJECT_ID]
```

**Solution:**
```bash
gcloud services enable pubsub.googleapis.com
gcloud services enable bigquery.googleapis.com
gcloud services enable bigquerydatatransfer.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com
```

**Wait 2-5 minutes** for API propagation, then retry `terraform apply`.

---

### 2. Permission Denied

**Error:**
```
Error 403: Permission denied / IAM policy error
```

**Solutions:**

**Option A - Use your user account:**
```bash
# Authenticate with your account
gcloud auth application-default login

# Verify you have necessary roles
gcloud projects get-iam-policy PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:user:YOUR_EMAIL"
```

**Option B - Grant required roles:**
```bash
# Grant Editor role (for testing)
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="user:YOUR_EMAIL" \
  --role="roles/editor"
```

**Option C - IAM bindings in Terraform failing:**

If you see "Cloud Resource Manager API" errors when creating IAM bindings, grant permissions manually:

```bash
# Get service account emails from Terraform output
terraform output

# Grant permissions manually
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:pubsub-bq-writer@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/bigquery.dataEditor"

gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:pubsub-bq-writer@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/bigquery.jobUser"

gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:bq-transfer-runner@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/bigquery.admin"
```

Then comment out IAM resources in `terraform/iam.tf` and re-run `terraform apply`.

---

### 3. No Data in Bronze Table

**Symptoms:**
- Producer is running
- No data appears in `bronze_transactions`

**Checks:**

```bash
# 1. Verify producer is connected
# Look for "[OK]" messages in producer output

# 2. Check Pub/Sub subscription
gcloud pubsub subscriptions describe bq-bronze-subscription

# 3. Check for messages in dead letter queue
bq query --nouse_legacy_sql \
  "SELECT COUNT(*) FROM \`PROJECT_ID.fraud_detection.bronze_transactions\`"

# 4. Check Cloud Logging for errors
gcloud logging read "resource.type=pubsub_subscription" --limit 20
```

**Common causes:**
- Producer authentication failed → Run `gcloud auth application-default login`
- Subscription not created → Check `terraform apply` output
- Schema mismatch → Verify Bronze table schema matches producer JSON

---

### 4. Silver/Gold Tables Empty

**Symptoms:**
- Bronze has data
- Silver or Gold tables are empty

**Solutions:**

**Check scheduled query status:**
```bash
bq ls --transfer_config --transfer_location=US
```

Look for `FAILED` or `PENDING` status.

**Check scheduled query logs:**
```bash
# Get transfer config ID from above command
bq show --transfer_config projects/PROJECT_NUMBER/locations/us/transferConfigs/CONFIG_ID

# Check run history
gcloud logging read "resource.type=bigquery_resource" --limit 10
```

**Common causes:**

**A. Timestamp parsing error:**
```
Error: Failed to parse input string "2026-02-07T15:02:10.572103Z"
```

**Solution**: Verify timestamp format in `terraform/main.tf` uses `%Y-%m-%dT%H:%M:%E*SZ` (includes microseconds).

**B. No data in time window:**

Silver/Gold queries filter by time (last 1 hour). If producer ran more than 1 hour ago, no data will be processed.

**Solution**: Run producer again or remove time filter temporarily.

**C. Manually trigger scheduled query:**

```bash
# Trigger Silver layer manually
bq query --nouse_legacy_sql \
  "INSERT INTO \`PROJECT_ID.fraud_detection.silver_transactions\` 
   SELECT JSON_EXTRACT_SCALAR(data, '\$.transaction_id') AS transaction_id, ...
   FROM \`PROJECT_ID.fraud_detection.bronze_transactions\` 
   WHERE JSON_EXTRACT_SCALAR(data, '\$.transaction_id') IS NOT NULL"
```

---

### 5. Producer Authentication Failed

**Error:**
```
google.auth.exceptions.DefaultCredentialsError: Your default credentials were not found
```

**Solution:**
```bash
gcloud auth application-default login
```

---

### 6. Producer Unicode/Emoji Errors (Windows)

**Error:**
```
UnicodeEncodeError: 'charmap' codec can't encode character
```

**Solution:** Already fixed in the current `producer.py` (all emojis removed).

If you still see this, edit `producer.py` and remove any emoji characters.

---

### 7. Terraform State Issues

**Error:**
```
Resource already exists but not in state
```

**Solution:**

**Option A - Import existing resource:**
```bash
terraform import google_pubsub_topic.fraud_events projects/PROJECT_ID/topics/banking-transactions
```

**Option B - Remove from GCP and recreate:**
```bash
# Delete the resource manually
gcloud pubsub topics delete banking-transactions

# Re-run terraform
terraform apply
```

**Option C - Reset state (use cautiously):**
```bash
# Remove from state only
terraform state rm google_pubsub_topic.fraud_events

# Re-import or recreate
terraform apply
```

---

### 8. BigQuery Schema Mismatch

**Error:**
```
Error 400: Required field [FIELD] not found in topic schema
Error 400: Field [FIELD] not found in table schema
```

**Solution:**

The Bronze table must have:
1. `data` (STRING) - stores the full JSON message
2. `subscription_name` (STRING) - metadata
3. `message_id` (STRING) - metadata
4. `publish_time` (TIMESTAMP) - metadata
5. `attributes` (STRING) - metadata

With `write_metadata = true` in the subscription config.

Verify schema:
```bash
bq show --format=prettyjson fraud_detection.bronze_transactions
```

---

### 9. Costs Higher Than Expected

**Check current costs:**
```bash
# View in console
https://console.cloud.google.com/billing

# Or via CLI
gcloud alpha billing accounts list
```

**Immediate cost reduction:**
```bash
# Stop producer
# Ctrl+C the producer script

# Destroy infrastructure
cd terraform
terraform destroy -auto-approve
```

See [BUDGET_GUIDE.md](BUDGET_GUIDE.md) for optimization strategies.

---

### 10. Terraform Destroy Fails

**Error:**
```
Error deleting [RESOURCE]: Resource is in use
```

**Solution:**

**Delete resources manually:**
```bash
# Delete BigQuery dataset (force delete with tables)
bq rm -r -f -d fraud_detection

# Delete Pub/Sub subscriptions
gcloud pubsub subscriptions delete bq-bronze-subscription
gcloud pubsub subscriptions delete dead-letter-subscription

# Delete Pub/Sub topics
gcloud pubsub topics delete banking-transactions
gcloud pubsub topics delete banking-transactions-dead-letter

# Delete service accounts
gcloud iam service-accounts delete pubsub-bq-writer@PROJECT_ID.iam.gserviceaccount.com
gcloud iam service-accounts delete bq-transfer-runner@PROJECT_ID.iam.gserviceaccount.com

# Retry terraform destroy
terraform destroy
```

---

## Getting More Help

### Check Logs

**BigQuery:**
```bash
gcloud logging read "resource.type=bigquery_resource" --limit 20
```

**Pub/Sub:**
```bash
gcloud logging read "resource.type=pubsub_subscription" --limit 20
```

**Scheduled Queries:**
```bash
gcloud logging read "resource.type=bigquery_dts_config" --limit 20
```

### Verify Resources

```bash
# List all Pub/Sub topics
gcloud pubsub topics list

# List all subscriptions
gcloud pubsub subscriptions list

# List BigQuery datasets
bq ls

# List tables in dataset
bq ls fraud_detection

# Check table schema
bq show fraud_detection.bronze_transactions
```

### Still Stuck?

1. Check the [README.md](../README.md) Quick Start section
2. Review [BUDGET_GUIDE.md](BUDGET_GUIDE.md) for cost issues
3. Examine Terraform state: `terraform show`
4. Check GCP Console for visual resource status
5. Review Cloud Logging for detailed error messages

---

## Prevention Tips

- Always enable APIs first before running Terraform
- Use `gcloud auth application-default login` for authentication
- Verify `.env` and `terraform.tfvars` are configured correctly
- Run `terraform plan` before `terraform apply`
- Always run `terraform destroy` when done testing
- Set up billing alerts at $5 threshold
- Keep producer running time limited during tests

---

**Remember**: Most issues are related to API enablement, authentication, or timing. Wait 2-5 minutes after enabling APIs before running Terraform!
