# Real-Time Banking Fraud Detection Pipeline

> Production-ready streaming data pipeline on GCP showcasing Medallion Architecture

[![GCP](https://img.shields.io/badge/GCP-Streaming-4285F4?logo=google-cloud)](https://cloud.google.com/)
[![Terraform](https://img.shields.io/badge/Terraform-IaC-7B42BC?logo=terraform)](https://www.terraform.io/)
[![Python](https://img.shields.io/badge/Python-3.8+-3776AB?logo=python)](https://www.python.org/)
[![BigQuery](https://img.shields.io/badge/BigQuery-Analytics-669DF6?logo=google-cloud)](https://cloud.google.com/bigquery)

**Portfolio-Ready** | **Production-Grade** | **Cost-Optimized** | **Test Under $2**

---

## What It Does

A **real-time fraud detection pipeline** that ingests banking transactions and processes them through a medallion architecture for analytics:

- **Real-time ingestion** via Pub/Sub to BigQuery (< 1 second latency)
- **Medallion architecture** with Bronze/Silver/Gold data layers
- **Automated transformations** using BigQuery scheduled queries
- **Infrastructure as Code** fully managed with Terraform
- **Budget-optimized** for testing under $2

---

## Architecture

```
┌─────────────────┐
│ Python Producer │  Generates synthetic banking transactions (1 TPS)
└────────┬────────┘
         │ JSON Messages via Pub/Sub
         ▼
┌─────────────────────────────────────────────────────────────┐
│                    MEDALLION ARCHITECTURE                    │
├─────────────────────────────────────────────────────────────┤
│ BRONZE LAYER (Raw Data)                                     │
│    └─ Real-time ingestion via Pub/Sub → BigQuery            │
│       Latency: < 1 second                                   │
├─────────────────────────────────────────────────────────────┤
│ SILVER LAYER (Cleaned & Enriched)                           │
│    └─ Scheduled transformations every 30 minutes            │
│       • Merchant categorization                             │
│       • Risk score calculation                              │
│       • Temporal features (hour, day)                       │
├─────────────────────────────────────────────────────────────┤
│ GOLD LAYER (Aggregated Metrics)                             │
│    └─ Business-ready metrics updated hourly                 │
│       • Fraud statistics & rates                            │
│       • Merchant analytics                                  │
└─────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────┐
│ Looker Studio   │  Real-time fraud detection dashboards
└─────────────────┘
```

---

## Project Structure

```
gcp-streaming-project/
│
├── README.md                    # You are here
├── .env.example                 # Environment variables template
├── .gitignore                   # Git ignore rules
│
├── docs/                        # Documentation
│   ├── BUDGET_GUIDE.md         # How to test for under $2
│   └── TROUBLESHOOTING.md      # Common issues & solutions
│
├── scripts/                     # Automation scripts
│   ├── README.md               # Script documentation
│   ├── stop-pipeline.sh        # Stop pipeline (Linux/Mac)
│   ├── stop-pipeline.bat       # Stop pipeline (Windows)
│   ├── resume-pipeline.sh      # Resume pipeline (Linux/Mac)
│   └── resume-pipeline.bat     # Resume pipeline (Windows)
│
├── terraform/                   # Infrastructure as Code
│   ├── main.tf                 # Core infrastructure
│   ├── variables.tf            # Variable definitions
│   ├── iam.tf                  # Service accounts & IAM
│   ├── monitoring.tf           # Dead letter queue
│   ├── outputs.tf              # Output values
│   └── terraform.tfvars.example # Configuration template
│
├── producer/                    # Data generator
│   ├── producer.py             # Transaction generator
│   └── requirements.txt        # Python dependencies
│
└── sql/                         # Reference queries
    ├── silver_layer.sql        # Bronze → Silver transformation
    ├── gold_fraud_metrics.sql  # Fraud metrics aggregation
    └── gold_merchant_analytics.sql # Merchant analytics
```

---

## Quick Start

### Prerequisites

- GCP Project with billing enabled
- `gcloud` CLI installed and authenticated
- Terraform >= 1.0
- Python 3.8+

### Step 1: Enable GCP APIs

```bash
# Set your project ID
export PROJECT_ID="your-project-id"
gcloud config set project $PROJECT_ID

# Enable required APIs (takes 2-3 minutes)
gcloud services enable pubsub.googleapis.com \
  bigquery.googleapis.com \
  bigquerydatatransfer.googleapis.com \
  cloudresourcemanager.googleapis.com
```

### Step 2: Authenticate

```bash
# Use Application Default Credentials
gcloud auth application-default login
```

### Step 3: Configure Environment

```bash
# Copy environment template
cp .env.example .env

# Edit .env and set your project ID
# GCP_PROJECT_ID=your-project-id
# PUBSUB_TOPIC_ID=banking-transactions
# TPS=1
```

### Step 4: Configure Terraform

```bash
cd terraform

# Copy terraform config template
cp terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars and set your project ID
# project_id = "your-project-id"
# region     = "us-central1"
# credentials_file = ""  # Leave empty if using ADC
```

### Step 5: Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Deploy (takes 3-5 minutes)
terraform apply
```

### Step 6: Start Producer

```bash
cd ../producer

# Install dependencies
pip install -r requirements.txt

# Start generating transactions (Ctrl+C to stop)
python producer.py
```

### Step 7: Verify Data Flow

```bash
# Check Bronze layer (immediate)
bq query --nouse_legacy_sql \
  "SELECT COUNT(*) as count FROM \`your-project-id.fraud_detection.bronze_transactions\`"

# Check Silver layer (after 30 minutes)
bq query --nouse_legacy_sql \
  "SELECT * FROM \`your-project-id.fraud_detection.silver_transactions\` LIMIT 5"

# Check Gold layer (after 1 hour)
bq query --nouse_legacy_sql \
  "SELECT * FROM \`your-project-id.fraud_detection.gold_fraud_metrics\` LIMIT 5"
```

### Step 8: Stop/Pause Pipeline (Cost Savings)

To pause the pipeline without losing data, use the automation scripts:

```bash
# Linux/Mac
./scripts/stop-pipeline.sh

# Windows
scripts\stop-pipeline.bat
```

This stops all expensive operations while preserving your data (< $0.10/month).

To resume later:
```bash
# Linux/Mac
./scripts/resume-pipeline.sh

# Windows  
scripts\resume-pipeline.bat
```

See detailed stop/resume instructions in [docs/BUDGET_GUIDE.md](docs/BUDGET_GUIDE.md#stopping-and-resuming-the-pipeline)

### Step 9: Full Cleanup

```bash
# IMPORTANT: Destroy all infrastructure to avoid charges
cd terraform
terraform destroy
```

---

## Cost Optimization

### Expected Costs

**Budget Mode (testing):**
- 15-minute test: **~$0.50**
- 1-hour test: **~$1.00**
- Full-day test: **~$3-5**

**Standard Mode (production):**
- ~$20-40/month for continuous operation

Most costs are covered by GCP free tier during testing!

See [docs/BUDGET_GUIDE.md](docs/BUDGET_GUIDE.md) for detailed optimization strategies.

---

## Key Features

### Data Engineering
- Real-time ingestion with Pub/Sub to BigQuery
- Medallion architecture (Bronze → Silver → Gold)
- Automated ETL with BigQuery scheduled queries
- JSON parsing and data enrichment

### Infrastructure
- Infrastructure as Code with Terraform
- Serverless, auto-scaling architecture
- Service account authentication
- Dead letter queue for error handling

### Observability
- Cloud Logging for error tracking
- BigQuery job monitoring
- Fraud rate tracking

---

## Sample Data Flow

### Bronze Record (Raw JSON in `data` column)
```json
{
  "transaction_id": "a7c3d8f1-2b4e-4f1a-8c9d-3e5f6a7b8c9d",
  "user_id": "user_0456",
  "amount": 67.45,
  "merchant": "Amazon",
  "timestamp": "2024-01-15T14:32:18.123456Z",
  "is_fraud_candidate": false
}
```

### Silver Record (Enriched)
```json
{
  "transaction_id": "a7c3d8f1-2b4e-4f1a-8c9d-3e5f6a7b8c9d",
  "merchant": "Amazon",
  "merchant_category": "E-commerce",
  "amount": 67.45,
  "risk_score": 0.1,
  "amount_bucket": "Medium ($50-$200)",
  "hour_of_day": 14,
  "day_of_week": "Monday"
}
```

### Gold Record (Aggregated Metrics)
```json
{
  "metric_timestamp": "2024-01-15T14:00:00Z",
  "total_transactions": 720,
  "fraud_transactions": 36,
  "fraud_rate": 0.05,
  "total_volume": 48567.89,
  "top_merchant": "Amazon",
  "high_risk_users_count": 12
}
```

---

## Looker Studio Dashboard

Connect to Gold layer tables for visualization:

**Recommended Charts:**
1. **Fraud Rate Over Time** (Line Chart) - Shows trends in fraud detection
2. **Transaction Volume** (Scorecard) - Total transactions processed
3. **Top Merchants by Volume** (Bar Chart) - Merchant transaction distribution
4. **Fraud Distribution** (Pie Chart) - Fraudulent vs legitimate transactions
5. **Hourly Metrics Table** - Real-time aggregated statistics

**Connection Info:**
- Project: `your-project-id`
- Dataset: `fraud_detection`
- Tables: `gold_fraud_metrics`, `gold_merchant_analytics`

---

## Tech Stack

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **Message Queue** | Google Cloud Pub/Sub | Real-time message streaming |
| **Data Warehouse** | BigQuery | Columnar storage & analytics |
| **ETL** | BigQuery Scheduled Queries | Automated transformations |
| **IaC** | Terraform | Infrastructure provisioning |
| **Producer** | Python 3.8+ | Synthetic data generation |
| **Monitoring** | Cloud Logging | Observability |
| **Visualization** | Looker Studio | BI dashboards |

---

## What You'll Learn

By working with this project:

- **Cloud Architecture**: Designing scalable cloud-native solutions on GCP
- **DevOps**: Infrastructure as Code with Terraform
- **Data Engineering**: ETL pipelines and medallion architecture
- **Python**: Event generation and streaming data patterns
- **SQL**: Complex analytical queries and aggregations
- **Cost Optimization**: Efficient cloud resource utilization
- **Security**: IAM, service accounts, authentication

---

## Use Cases

This architecture can be adapted for:

- Real-time fraud detection (current implementation)
- Payment processing and authorization
- Customer behavior analytics (clickstream)
- Gaming telemetry and player actions
- IoT sensor data streaming
- Mobile app event tracking
- Healthcare monitoring and alerts

---

## Production Enhancements (Future)

For production environments, consider adding:

- **CI/CD Pipeline**: GitHub Actions for automated Terraform deployments
- **Multi-environment**: Separate dev/staging/prod GCP projects
- **Data Quality**: dbt tests or Great Expectations
- **Advanced Monitoring**: Datadog, custom Cloud Monitoring alerts
- **Secret Management**: GCP Secret Manager integration
- **Containerization**: Docker + Cloud Run for producer scalability

---

## Troubleshooting

Common issues? Check [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)

Quick checks:
```bash
# Check Terraform state
terraform show

# Check BigQuery tables
bq ls fraud_detection

# Check Pub/Sub subscriptions
gcloud pubsub subscriptions list

# Check scheduled queries
bq ls --transfer_config --transfer_location=US
```

---

## Documentation

| Document | Description |
|----------|-------------|
| [BUDGET_GUIDE.md](docs/BUDGET_GUIDE.md) | How to test for under $2 + Stop/Resume instructions |
| [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Common issues and solutions |
| [scripts/README.md](scripts/README.md) | Pipeline management automation scripts |

---

## License

MIT License - Free to use for learning and portfolio purposes.

---

## Author
@aurelpow
Data | ML Engineer