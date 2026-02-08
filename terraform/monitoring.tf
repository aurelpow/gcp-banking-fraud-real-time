# Monitoring and Alerting Configuration

# Pub/Sub Dead Letter Topic for failed messages
# Purpose:
# - Captures failed messages
# - Allows debugging of ingestion errors
# - Prevents message loss
resource "google_pubsub_topic" "dead_letter" {
  name = "${var.topic_name}-dead-letter"
}

resource "google_pubsub_subscription" "dead_letter_sub" {
  name  = "dead-letter-subscription"
  topic = google_pubsub_topic.dead_letter.name

  ack_deadline_seconds = 60

  expiration_policy {
    ttl = "" # Never expire
  }
}

# Note: Advanced monitoring (logging sink, alerts, custom metrics) has been 
# disabled for simplicity and to avoid permission issues during initial setup.
# They can be enabled later if needed.
# 
# To enable full monitoring:
# 1. Ensure you have logging.admin and monitoring.editor roles
# 2. Uncomment the resources in the original monitoring.tf
# 3. Run: terraform apply
