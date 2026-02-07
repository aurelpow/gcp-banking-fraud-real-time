-- Gold Layer - Merchant Analytics
-- This query creates per-merchant metrics for business intelligence
-- Runs every 15 minutes via scheduled query

INSERT INTO `{project_id}.fraud_detection.gold_merchant_analytics`
SELECT 
  merchant,
  merchant_category,
  TIMESTAMP_TRUNC(transaction_timestamp, HOUR) AS metric_timestamp,
  COUNT(*) AS transaction_count,
  COUNTIF(is_fraud_candidate) AS fraud_count,
  SAFE_DIVIDE(COUNTIF(is_fraud_candidate), COUNT(*)) AS fraud_rate,
  SUM(amount) AS total_volume,
  AVG(amount) AS avg_transaction_amount
FROM `{project_id}.fraud_detection.silver_transactions`
WHERE transaction_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
GROUP BY merchant, merchant_category, metric_timestamp
HAVING CONCAT(merchant, '_', CAST(metric_timestamp AS STRING)) NOT IN (
  SELECT CONCAT(merchant, '_', CAST(metric_timestamp AS STRING))
  FROM `{project_id}.fraud_detection.gold_merchant_analytics`
);
