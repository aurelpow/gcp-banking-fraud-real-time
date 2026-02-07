# Terraform Outputs

output "project_id" {
  description = "GCP Project ID"
  value       = var.project_id
}

output "pubsub_topic" {
  description = "Pub/Sub topic name"
  value       = google_pubsub_topic.fraud_events.name
}

output "pubsub_topic_path" {
  description = "Full Pub/Sub topic path"
  value       = google_pubsub_topic.fraud_events.id
}

output "dataset_id" {
  description = "BigQuery dataset ID"
  value       = google_bigquery_dataset.medallion_db.dataset_id
}

output "bronze_table" {
  description = "Bronze layer table"
  value       = "${var.project_id}.${google_bigquery_dataset.medallion_db.dataset_id}.${google_bigquery_table.bronze_transactions.table_id}"
}

output "silver_table" {
  description = "Silver layer table"
  value       = "${var.project_id}.${google_bigquery_dataset.medallion_db.dataset_id}.${google_bigquery_table.silver_transactions.table_id}"
}

output "gold_fraud_metrics_table" {
  description = "Gold layer fraud metrics table"
  value       = "${var.project_id}.${google_bigquery_dataset.medallion_db.dataset_id}.${google_bigquery_table.gold_fraud_metrics.table_id}"
}

output "gold_merchant_analytics_table" {
  description = "Gold layer merchant analytics table"
  value       = "${var.project_id}.${google_bigquery_dataset.medallion_db.dataset_id}.${google_bigquery_table.gold_merchant_analytics.table_id}"
}

output "bq_subscription" {
  description = "BigQuery subscription name"
  value       = google_pubsub_subscription.bq_sub.name
}

output "dead_letter_topic" {
  description = "Dead letter topic for failed messages"
  value       = google_pubsub_topic.dead_letter.name
}

output "looker_studio_connection_info" {
  description = "Information for connecting Looker Studio"
  value = {
    project_id = var.project_id
    dataset_id = google_bigquery_dataset.medallion_db.dataset_id
    gold_tables = [
      google_bigquery_table.gold_fraud_metrics.table_id,
      google_bigquery_table.gold_merchant_analytics.table_id
    ]
  }
}
