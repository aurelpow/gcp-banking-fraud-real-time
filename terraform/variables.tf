variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "credentials_file" {
  description = "Path to GCP service account key file"
  type        = string
  default     = ""
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "dataset_location" {
  description = "BigQuery Dataset Location"
  type        = string
  default     = "US"
}

variable "topic_name" {
  description = "Pub/Sub Topic Name"
  type        = string
  default     = "banking-transactions"
}

variable "dataset_id" {
  description = "BigQuery Dataset ID"
  type        = string
  default     = "fraud_detection"
}
