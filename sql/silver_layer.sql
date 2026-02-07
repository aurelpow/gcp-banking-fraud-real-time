-- Silver Layer Transformation Query
-- This query transforms raw Bronze data into cleaned and enriched Silver data
-- Runs every 30 minutes via scheduled query
-- Parses JSON from the 'data' column in Bronze layer

INSERT INTO `{project_id}.fraud_detection.silver_transactions`
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
  PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%S', JSON_EXTRACT_SCALAR(data, '$.timestamp')) AS transaction_timestamp,
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
  EXTRACT(HOUR FROM PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%S', JSON_EXTRACT_SCALAR(data, '$.timestamp'))) AS hour_of_day,
  FORMAT_TIMESTAMP('%A', PARSE_TIMESTAMP('%Y-%m-%dT%H:%M:%S', JSON_EXTRACT_SCALAR(data, '$.timestamp'))) AS day_of_week,
  CURRENT_TIMESTAMP() AS ingestion_timestamp
FROM `{project_id}.fraud_detection.bronze_transactions`
WHERE JSON_EXTRACT_SCALAR(data, '$.transaction_id') IS NOT NULL
  AND JSON_EXTRACT_SCALAR(data, '$.transaction_id') NOT IN (
    SELECT transaction_id 
    FROM `{project_id}.fraud_detection.silver_transactions`
  )
  AND publish_time > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR);

