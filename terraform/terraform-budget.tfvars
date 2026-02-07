# Budget Testing Configuration
# Use this for minimal cost testing (under $2)

project_id = "your-project-id-here"
region     = "us-central1"
credentials_file = "./service-account-key.json"

# These are the default settings but optimized for budget
dataset_location = "US"  # Multi-region, often cheaper for small workloads
topic_name = "banking-transactions"
dataset_id = "fraud_detection"
