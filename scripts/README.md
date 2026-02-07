# Pipeline Management Scripts

Automation scripts to stop and resume the streaming pipeline for cost savings.

---

## Scripts

### `stop-pipeline.sh` / `stop-pipeline.bat`

**Purpose**: Stop all streaming operations to save costs while preserving data

**What it does:**
- Disables all BigQuery scheduled queries
- Deletes Pub/Sub subscriptions (keeps topics)
- Preserves all data in BigQuery tables
- Checks for running producer process

**Usage:**

```bash
# Linux/Mac
./scripts/stop-pipeline.sh

# Windows
scripts\stop-pipeline.bat
```

**Result:**
- No more data ingestion or processing
- Cost reduced to ~$0.02-0.10/month (storage only)
- All historical data intact

---

### `resume-pipeline.sh` / `resume-pipeline.bat`

**Purpose**: Resume streaming operations after stopping

**What it does:**
- Recreates Pub/Sub subscriptions via Terraform
- Re-enables all BigQuery scheduled queries
- Verifies pipeline is ready to receive data

**Usage:**

```bash
# Linux/Mac
./scripts/resume-pipeline.sh

# Windows
scripts\resume-pipeline.bat
```

**Next steps after resume:**
1. Start the producer: `python producer/producer.py`
2. Verify data flow in BigQuery

---

## When to Use

### Stop the Pipeline When:
- Testing is complete but you want to keep the data
- Taking a break from development
- Showing the project to someone later (no need to regenerate data)
- Want to avoid costs overnight/weekend

### Resume the Pipeline When:
- Ready to generate more data
- Adding new features that require testing
- Demonstrating the live pipeline
- Need to update gold layer metrics

---

## Cost Comparison

| State | Monthly Cost | What's Running |
|-------|--------------|----------------|
| **Running** | $20-40 | All streaming + queries + storage |
| **Stopped** | $0.02-0.10 | Storage only |
| **Destroyed** | $0.00 | Nothing (data deleted) |

---

## Requirements

### Linux/Mac Scripts
- `bash` shell
- `gcloud` CLI installed and authenticated
- `bq` CLI (comes with gcloud)
- `jq` (optional, for better formatting)

### Windows Scripts
- `cmd.exe` or PowerShell
- `gcloud` CLI installed and authenticated
- `bq` CLI (comes with gcloud)

---

## Make Scripts Executable (Linux/Mac)

```bash
chmod +x scripts/stop-pipeline.sh
chmod +x scripts/resume-pipeline.sh
```

---

## Troubleshooting

### "No GCP project configured"
```bash
gcloud config set project YOUR_PROJECT_ID
```

### "terraform/ directory not found"
Run the scripts from the project root directory (where README.md is located)

### "Failed to disable scheduled query"
Manually disable in GCP Console:
1. Go to BigQuery → Scheduled queries
2. Click on the query
3. Click "Disable"

### Subscriptions not recreating
Run full terraform apply:
```bash
cd terraform
terraform apply
```

---

## Alternative: Manual Steps

If scripts don't work, follow the manual steps in [docs/BUDGET_GUIDE.md](../docs/BUDGET_GUIDE.md#stopping-and-resuming-the-pipeline)

---

## Questions?

See [TROUBLESHOOTING.md](../docs/TROUBLESHOOTING.md) for common issues.
