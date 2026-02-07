-- Gold Layer - Fraud Metrics Aggregation
-- This query creates hourly fraud metrics for dashboard visualization
-- Runs every 10 minutes via scheduled query

INSERT INTO `{project_id}.fraud_detection.gold_fraud_metrics`
WITH time_window AS (
  SELECT 
    TIMESTAMP_TRUNC(transaction_timestamp, HOUR) AS metric_timestamp,
    COUNT(*) AS total_transactions,
    COUNTIF(is_fraud_candidate) AS fraud_transactions,
    SUM(amount) AS total_volume,
    SUM(IF(is_fraud_candidate, amount, 0)) AS fraud_volume,
    AVG(amount) AS avg_transaction_amount,
    AVG(IF(is_fraud_candidate, amount, NULL)) AS avg_fraud_amount
  FROM `{project_id}.fraud_detection.silver_transactions`
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
    FROM `{project_id}.fraud_detection.silver_transactions`
    WHERE transaction_timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
    GROUP BY metric_timestamp, merchant
  )
  GROUP BY metric_timestamp
),
high_risk_users AS (
  SELECT 
    TIMESTAMP_TRUNC(transaction_timestamp, HOUR) AS metric_timestamp,
    COUNT(DISTINCT user_id) AS high_risk_users_count
  FROM `{project_id}.fraud_detection.silver_transactions`
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
  FROM `{project_id}.fraud_detection.gold_fraud_metrics`
);
