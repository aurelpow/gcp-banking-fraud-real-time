# IAM configuration for the streaming pipeline

# Service Account for Pub/Sub to BigQuery
resource "google_service_account" "pubsub_bq_sa" {
  account_id   = "pubsub-bq-writer"
  display_name = "Pub/Sub to BigQuery Writer"
  description  = "Service account for Pub/Sub to write to BigQuery"
}

# Grant BigQuery Data Editor role to the service account
# COMMENTED OUT: Granted manually via gcloud due to Cloud Resource Manager API propagation delay
# resource "google_project_iam_member" "pubsub_bq_editor" {
#   project = var.project_id
#   role    = "roles/bigquery.dataEditor"
#   member  = "serviceAccount:${google_service_account.pubsub_bq_sa.email}"
# }

# Grant BigQuery Job User role to the service account
# COMMENTED OUT: Granted manually via gcloud due to Cloud Resource Manager API propagation delay
# resource "google_project_iam_member" "pubsub_bq_job_user" {
#   project = var.project_id
#   role    = "roles/bigquery.jobUser"
#   member  = "serviceAccount:${google_service_account.pubsub_bq_sa.email}"
# }

# Service account for scheduled queries
resource "google_service_account" "bq_transfer_sa" {
  account_id   = "bq-transfer-runner"
  display_name = "BigQuery Transfer Service Account"
  description  = "Service account for running BigQuery scheduled queries"
}

# Grant BigQuery Admin role for scheduled queries
# COMMENTED OUT: Granted manually via gcloud due to Cloud Resource Manager API propagation delay
# resource "google_project_iam_member" "bq_transfer_admin" {
#   project = var.project_id
#   role    = "roles/bigquery.admin"
#   member  = "serviceAccount:${google_service_account.bq_transfer_sa.email}"
# }
