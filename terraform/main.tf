# terraform/main.tf
provider "google" {
  project     = var.project_id
  region      = var.region
  credentials = var.credentials_file != "" ? file(var.credentials_file) : null
}

# 1. The Entry Point: Pub/Sub Topic
resource "google_pubsub_topic" "fraud_events" {
  name = var.topic_name
}

# 2. The Bronze Layer: BigQuery Dataset
resource "google_bigquery_dataset" "medallion_db" {
  dataset_id = var.dataset_id
  location   = var.dataset_location
}

# 3. The Bronze Table (Raw Data)
resource "google_bigquery_table" "bronze_transactions" {
  dataset_id          = google_bigquery_dataset.medallion_db.dataset_id
  table_id            = "bronze_transactions"
  deletion_protection = false

  schema = <<EOF
[
  {"name": "data", "type": "STRING", "mode": "NULLABLE"},
  {"name": "subscription_name", "type": "STRING", "mode": "NULLABLE"},
  {"name": "message_id", "type": "STRING", "mode": "NULLABLE"},
  {"name": "publish_time", "type": "TIMESTAMP", "mode": "NULLABLE"},
  {"name": "attributes", "type": "STRING", "mode": "NULLABLE"}
]
EOF
}

# 4. The "Magic" Link: BigQuery Subscription
resource "google_pubsub_subscription" "bq_sub" {
  name  = "bq-bronze-subscription"
  topic = google_pubsub_topic.fraud_events.name

  bigquery_config {
    table            = "${var.project_id}.${google_bigquery_table.bronze_transactions.dataset_id}.${google_bigquery_table.bronze_transactions.table_id}"
    use_topic_schema = false
    write_metadata   = true
  }

  depends_on = [google_bigquery_table.bronze_transactions]
}

# 5. The Silver Layer: Cleaned and Enriched Data
resource "google_bigquery_table" "silver_transactions" {
  dataset_id          = google_bigquery_dataset.medallion_db.dataset_id
  table_id            = "silver_transactions"
  deletion_protection = false

  schema = <<EOF
[
  {"name": "transaction_id", "type": "STRING", "mode": "REQUIRED"},
  {"name": "user_id", "type": "STRING", "mode": "REQUIRED"},
  {"name": "amount", "type": "FLOAT", "mode": "REQUIRED"},
  {"name": "merchant", "type": "STRING", "mode": "REQUIRED"},
  {"name": "merchant_category", "type": "STRING", "mode": "NULLABLE"},
  {"name": "transaction_timestamp", "type": "TIMESTAMP", "mode": "REQUIRED"},
  {"name": "is_fraud_candidate", "type": "BOOLEAN", "mode": "REQUIRED"},
  {"name": "risk_score", "type": "FLOAT", "mode": "NULLABLE"},
  {"name": "amount_bucket", "type": "STRING", "mode": "NULLABLE"},
  {"name": "hour_of_day", "type": "INTEGER", "mode": "NULLABLE"},
  {"name": "day_of_week", "type": "STRING", "mode": "NULLABLE"},
  {"name": "ingestion_timestamp", "type": "TIMESTAMP", "mode": "NULLABLE"}
]
EOF
}

# 6. The Gold Layer: Aggregated Metrics
resource "google_bigquery_table" "gold_fraud_metrics" {
  dataset_id          = google_bigquery_dataset.medallion_db.dataset_id
  table_id            = "gold_fraud_metrics"
  deletion_protection = false

  schema = <<EOF
[
  {"name": "metric_timestamp", "type": "TIMESTAMP", "mode": "REQUIRED"},
  {"name": "total_transactions", "type": "INTEGER", "mode": "REQUIRED"},
  {"name": "fraud_transactions", "type": "INTEGER", "mode": "REQUIRED"},
  {"name": "fraud_rate", "type": "FLOAT", "mode": "REQUIRED"},
  {"name": "total_volume", "type": "FLOAT", "mode": "REQUIRED"},
  {"name": "fraud_volume", "type": "FLOAT", "mode": "REQUIRED"},
  {"name": "avg_transaction_amount", "type": "FLOAT", "mode": "NULLABLE"},
  {"name": "avg_fraud_amount", "type": "FLOAT", "mode": "NULLABLE"},
  {"name": "top_merchant", "type": "STRING", "mode": "NULLABLE"},
  {"name": "high_risk_users_count", "type": "INTEGER", "mode": "NULLABLE"}
]
EOF
}

# 7. Gold Layer: Merchant Analytics
resource "google_bigquery_table" "gold_merchant_analytics" {
  dataset_id          = google_bigquery_dataset.medallion_db.dataset_id
  table_id            = "gold_merchant_analytics"
  deletion_protection = false

  schema = <<EOF
[
  {"name": "merchant", "type": "STRING", "mode": "REQUIRED"},
  {"name": "merchant_category", "type": "STRING", "mode": "NULLABLE"},
  {"name": "metric_timestamp", "type": "TIMESTAMP", "mode": "REQUIRED"},
  {"name": "transaction_count", "type": "INTEGER", "mode": "REQUIRED"},
  {"name": "fraud_count", "type": "INTEGER", "mode": "REQUIRED"},
  {"name": "fraud_rate", "type": "FLOAT", "mode": "REQUIRED"},
  {"name": "total_volume", "type": "FLOAT", "mode": "REQUIRED"},
  {"name": "avg_transaction_amount", "type": "FLOAT", "mode": "NULLABLE"}
]
EOF
}

# 8. Scheduled Query for Silver Layer Transformation
resource "google_bigquery_data_transfer_config" "silver_layer_etl" {
  display_name           = "silver-layer-transformation"
  location               = var.dataset_location
  data_source_id         = "scheduled_query"
  schedule               = "every 30 minutes"
  destination_dataset_id = google_bigquery_dataset.medallion_db.dataset_id
  service_account_name   = google_service_account.bq_transfer_sa.email

  params = {
    query = <<-SQL
      INSERT INTO `${var.project_id}.${google_bigquery_dataset.medallion_db.dataset_id}.silver_transactions`
      SELECT 
        JSON_EXTRACT_SCALAR(data, '$.transaction_id') AS transaction_id,
        JSON_EXTRACT_SCALAR(data, '$.user_id') AS user_id,
        CAST(JSON_EXTRACT_SCALAR(data, '$.amount') AS FLOAT64) AS amount,
        JSON_EXTRACT_SCALAR(data, '$.merchant') AS merchant,
        -- Categorize merchants
        CASE 
          WHEN JSON_EXTRACT_SCALAR(data, '$.merchant') IN ('Amazon', 'Apple', 'Steam') THEN 'E-commerce'
          WHEN JSON_EXTRACT_SCALAR(data, '$.merchant') IN ('Walmart', 'Target') THEN 'Retail'
          WHEN JSON_EXTRACT_SCALAR(data, '$.merchant') = 'Local_Cafe' THEN 'Food & Beverage'
          WHEN JSON_EXTRACT_SCALAR(data, '$.merchant') = 'Gas_Station' THEN 'Fuel'
          ELSE 'Other'
        END AS merchant_category,
        PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*SZ', JSON_EXTRACT_SCALAR(data, '$.timestamp')) AS transaction_timestamp,
        CAST(JSON_EXTRACT_SCALAR(data, '$.is_fraud_candidate') AS BOOL) AS is_fraud_candidate,
        -- Calculate risk score based on amount and fraud flag
        CASE 
          WHEN CAST(JSON_EXTRACT_SCALAR(data, '$.is_fraud_candidate') AS BOOL) 
               AND CAST(JSON_EXTRACT_SCALAR(data, '$.amount') AS FLOAT64) > 1000 THEN 0.9
          WHEN CAST(JSON_EXTRACT_SCALAR(data, '$.is_fraud_candidate') AS BOOL) THEN 0.7
          WHEN CAST(JSON_EXTRACT_SCALAR(data, '$.amount') AS FLOAT64) > 500 THEN 0.3
          ELSE 0.1
        END AS risk_score,
        -- Bucket amounts for analysis
        CASE 
          WHEN CAST(JSON_EXTRACT_SCALAR(data, '$.amount') AS FLOAT64) < 50 THEN 'Small (<$50)'
          WHEN CAST(JSON_EXTRACT_SCALAR(data, '$.amount') AS FLOAT64) < 200 THEN 'Medium ($50-$200)'
          WHEN CAST(JSON_EXTRACT_SCALAR(data, '$.amount') AS FLOAT64) < 1000 THEN 'Large ($200-$1000)'
          ELSE 'Very Large (>$1000)'
        END AS amount_bucket,
        EXTRACT(HOUR FROM PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*SZ', JSON_EXTRACT_SCALAR(data, '$.timestamp'))) AS hour_of_day,
        FORMAT_TIMESTAMP('%A', PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%E*SZ', JSON_EXTRACT_SCALAR(data, '$.timestamp'))) AS day_of_week,
        CURRENT_TIMESTAMP() AS ingestion_timestamp
      FROM `${var.project_id}.${google_bigquery_dataset.medallion_db.dataset_id}.bronze_transactions`
      WHERE JSON_EXTRACT_SCALAR(data, '$.transaction_id') IS NOT NULL
        AND JSON_EXTRACT_SCALAR(data, '$.transaction_id') NOT IN (
          SELECT transaction_id 
          FROM `${var.project_id}.${google_bigquery_dataset.medallion_db.dataset_id}.silver_transactions`
        )
        AND publish_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
    SQL
  }

  depends_on = [
    google_bigquery_table.bronze_transactions,
    google_bigquery_table.silver_transactions
  ]
}

# 9. Scheduled Query for Gold Layer - Fraud Metrics
resource "google_bigquery_data_transfer_config" "gold_fraud_metrics_etl" {
  display_name           = "gold-fraud-metrics-aggregation"
  location               = var.dataset_location
  data_source_id         = "scheduled_query"
  schedule               = "every 1 hours"
  destination_dataset_id = google_bigquery_dataset.medallion_db.dataset_id
  service_account_name   = google_service_account.bq_transfer_sa.email

  params = {
    query = <<-SQL
      INSERT INTO `${var.project_id}.${google_bigquery_dataset.medallion_db.dataset_id}.gold_fraud_metrics`
      WITH time_window AS (
        SELECT 
          TIMESTAMP_TRUNC(transaction_timestamp, HOUR) AS metric_timestamp,
          COUNT(*) AS total_transactions,
          COUNTIF(is_fraud_candidate) AS fraud_transactions,
          SUM(amount) AS total_volume,
          SUM(IF(is_fraud_candidate, amount, 0)) AS fraud_volume,
          AVG(amount) AS avg_transaction_amount,
          AVG(IF(is_fraud_candidate, amount, NULL)) AS avg_fraud_amount
        FROM `${var.project_id}.${google_bigquery_dataset.medallion_db.dataset_id}.silver_transactions`
        WHERE transaction_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
        GROUP BY metric_timestamp
      ),
      top_merchants AS (
        SELECT 
          metric_timestamp,
          ARRAY_AGG(merchant ORDER BY transaction_count DESC LIMIT 1)[OFFSET(0)] AS top_merchant
        FROM (
          SELECT 
            TIMESTAMP_TRUNC(transaction_timestamp, HOUR) AS metric_timestamp,
            merchant,
            COUNT(*) AS transaction_count
          FROM `${var.project_id}.${google_bigquery_dataset.medallion_db.dataset_id}.silver_transactions`
          WHERE transaction_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
          GROUP BY metric_timestamp, merchant
        )
        GROUP BY metric_timestamp
      ),
      high_risk_users AS (
        SELECT 
          TIMESTAMP_TRUNC(transaction_timestamp, HOUR) AS metric_timestamp,
          COUNT(DISTINCT user_id) AS high_risk_users_count
        FROM `${var.project_id}.${google_bigquery_dataset.medallion_db.dataset_id}.silver_transactions`
        WHERE risk_score >= 0.7
          AND transaction_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
        GROUP BY metric_timestamp
      )
      SELECT 
        tw.metric_timestamp,
        tw.total_transactions,
        tw.fraud_transactions,
        SAFE_DIVIDE(tw.fraud_transactions, tw.total_transactions) AS fraud_rate,
        tw.total_volume,
        tw.fraud_volume,
        tw.avg_transaction_amount,
        tw.avg_fraud_amount,
        tm.top_merchant,
        COALESCE(hru.high_risk_users_count, 0) AS high_risk_users_count
      FROM time_window tw
      LEFT JOIN top_merchants tm ON tw.metric_timestamp = tm.metric_timestamp
      LEFT JOIN high_risk_users hru ON tw.metric_timestamp = hru.metric_timestamp
      WHERE tw.metric_timestamp NOT IN (
        SELECT metric_timestamp 
        FROM `${var.project_id}.${google_bigquery_dataset.medallion_db.dataset_id}.gold_fraud_metrics`
      )
    SQL
  }

  depends_on = [
    google_bigquery_table.silver_transactions,
    google_bigquery_table.gold_fraud_metrics
  ]
}

# 10. Scheduled Query for Gold Layer - Merchant Analytics
resource "google_bigquery_data_transfer_config" "gold_merchant_analytics_etl" {
  display_name           = "gold-merchant-analytics-aggregation"
  location               = var.dataset_location
  data_source_id         = "scheduled_query"
  schedule               = "every 1 hours"
  destination_dataset_id = google_bigquery_dataset.medallion_db.dataset_id
  service_account_name   = google_service_account.bq_transfer_sa.email

  params = {
    query = <<-SQL
      INSERT INTO `${var.project_id}.${google_bigquery_dataset.medallion_db.dataset_id}.gold_merchant_analytics`
      SELECT 
        merchant,
        merchant_category,
        TIMESTAMP_TRUNC(transaction_timestamp, HOUR) AS metric_timestamp,
        COUNT(*) AS transaction_count,
        COUNTIF(is_fraud_candidate) AS fraud_count,
        SAFE_DIVIDE(COUNTIF(is_fraud_candidate), COUNT(*)) AS fraud_rate,
        SUM(amount) AS total_volume,
        AVG(amount) AS avg_transaction_amount
      FROM `${var.project_id}.${google_bigquery_dataset.medallion_db.dataset_id}.silver_transactions`
      WHERE transaction_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
      GROUP BY merchant, merchant_category, metric_timestamp
      HAVING CONCAT(merchant, '_', CAST(metric_timestamp AS STRING)) NOT IN (
        SELECT CONCAT(merchant, '_', CAST(metric_timestamp AS STRING))
        FROM `${var.project_id}.${google_bigquery_dataset.medallion_db.dataset_id}.gold_merchant_analytics`
      )
    SQL
  }

  depends_on = [
    google_bigquery_table.silver_transactions,
    google_bigquery_table.gold_merchant_analytics
  ]
}