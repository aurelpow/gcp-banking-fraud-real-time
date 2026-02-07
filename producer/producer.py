# producer/producer.py
"""
Real-time Banking Transaction Producer for GCP Streaming Pipeline
Generates synthetic transaction data and publishes to Pub/Sub
"""

import json
import os
import random
import time
import uuid
from datetime import datetime
from typing import Dict, Any
from google.cloud import pubsub_v1
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

# Configuration from environment variables
PROJECT_ID = os.getenv("GCP_PROJECT_ID")
TOPIC_ID = os.getenv("PUBSUB_TOPIC_ID", "banking-transactions")
TRANSACTIONS_PER_SECOND = int(os.getenv("TPS", "2"))  # Configurable throughput

if not PROJECT_ID:
    raise ValueError("GCP_PROJECT_ID environment variable is required")

# Initialize Pub/Sub publisher
publisher = pubsub_v1.PublisherClient()
topic_path = publisher.topic_path(PROJECT_ID, TOPIC_ID)

# Merchant configurations for realistic data
MERCHANTS = {
    "Amazon": {"fraud_rate": 0.03, "avg_amount": 75},
    "Apple": {"fraud_rate": 0.02, "avg_amount": 150},
    "Steam": {"fraud_rate": 0.04, "avg_amount": 40},
    "Unknown_Vendor": {"fraud_rate": 0.15, "avg_amount": 300},
    "Local_Cafe": {"fraud_rate": 0.01, "avg_amount": 15},
    "Walmart": {"fraud_rate": 0.03, "avg_amount": 85},
    "Target": {"fraud_rate": 0.02, "avg_amount": 65},
    "Gas_Station": {"fraud_rate": 0.05, "avg_amount": 50},
}

# User profiles for realistic patterns
USERS = [f"user_{i:04d}" for i in range(100, 1000)]


def generate_transaction() -> Dict[str, Any]:
    """
    Generates a synthetic banking transaction with realistic patterns.

    Returns:
        Dict containing transaction details
    """
    merchant = random.choice(list(MERCHANTS.keys()))
    merchant_config = MERCHANTS[merchant]

    # Determine if this is a fraud candidate based on merchant's fraud rate
    is_fraud = random.random() < merchant_config["fraud_rate"]

    # Generate amount based on fraud flag and merchant average
    if is_fraud:
        # Fraudulent transactions tend to be higher
        amount = round(
            random.uniform(
                merchant_config["avg_amount"] * 5, merchant_config["avg_amount"] * 20
            ),
            2,
        )
    else:
        # Normal transactions vary around merchant average
        amount = round(
            random.gauss(
                merchant_config["avg_amount"], merchant_config["avg_amount"] * 0.3
            ),
            2,
        )
        amount = max(1.0, amount)  # Ensure positive amount

    # Occasionally generate very large transactions
    if random.random() < 0.01:
        amount = round(random.uniform(2000, 10000), 2)
        is_fraud = True

    transaction = {
        "transaction_id": str(uuid.uuid4()),
        "user_id": random.choice(USERS),
        "amount": amount,
        "merchant": merchant,
        "timestamp": datetime.utcnow().isoformat() + "Z",  # RFC3339 format for BigQuery
        "is_fraud_candidate": is_fraud,
    }

    return transaction


def publish_callback(future: pubsub_v1.publisher.futures.Future) -> None:
    """Callback for publish operation"""
    try:
        message_id = future.result()
    except Exception as e:
        print(f"❌ Error publishing message: {e}")


def main():
    """Main producer loop"""
    print("[START] Starting Real-time Transaction Producer")
    print(f"[TARGET] {TRANSACTIONS_PER_SECOND} transactions/second")
    print(f"[TOPIC] Publishing to: {topic_path}")
    print(f"[MERCHANTS] {', '.join(MERCHANTS.keys())}")
    print("-" * 80)

    transaction_count = 0
    start_time = time.time()

    try:
        while True:
            # Generate and publish transaction
            transaction = generate_transaction()
            message_json = json.dumps(transaction)

            # Publish to Pub/Sub asynchronously
            future = publisher.publish(
                topic_path,
                message_json.encode("utf-8"),
                transaction_id=transaction["transaction_id"],  # Add as attribute
            )
            future.add_done_callback(publish_callback)

            transaction_count += 1

            # Log transaction details
            fraud_indicator = "[FRAUD]" if transaction["is_fraud_candidate"] else "[OK]"
            print(
                f"{fraud_indicator} | "
                f"ID: {transaction['transaction_id'][:8]}... | "
                f"User: {transaction['user_id']} | "
                f"Merchant: {transaction['merchant']:15s} | "
                f"Amount: ${transaction['amount']:8.2f}"
            )

            # Stats every 100 transactions
            if transaction_count % 100 == 0:
                elapsed = time.time() - start_time
                rate = transaction_count / elapsed
                print(
                    f"\n[STATS] {transaction_count} transactions | Rate: {rate:.2f} TPS\n"
                )

            # Control throughput
            time.sleep(1.0 / TRANSACTIONS_PER_SECOND)

    except KeyboardInterrupt:
        print("\n[STOPPED] Producer stopped by user")
        elapsed = time.time() - start_time
        print(
            f"[STATS] Final Stats: {transaction_count} transactions in {elapsed:.2f}s"
        )
        print(f"[STATS] Average Rate: {transaction_count / elapsed:.2f} TPS")
    except Exception as e:
        print(f"[ERROR] Fatal error: {e}")
        raise


if __name__ == "__main__":
    main()
