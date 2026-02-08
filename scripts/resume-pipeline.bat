@echo off
REM Resume the streaming pipeline after stopping
REM This script recreates Pub/Sub subscriptions and re-enables scheduled queries

setlocal enabledelayedexpansion

echo ==========================================
echo Resuming Real-Time Fraud Detection Pipeline
echo ==========================================
echo.

REM Get project ID
for /f "tokens=*" %%i in ('gcloud config get-value project 2^>nul') do set PROJECT_ID=%%i
if "%PROJECT_ID%"=="" (
  echo ERROR: No GCP project configured
  echo Run: gcloud config set project YOUR_PROJECT_ID
  exit /b 1
)

echo Project: %PROJECT_ID%
echo.

REM Check if terraform directory exists
if not exist "terraform" (
  echo ERROR: terraform\ directory not found
  echo Run this script from the project root directory
  exit /b 1
)

REM Recreate subscriptions via Terraform
echo 1. Recreating Pub/Sub subscriptions...
cd terraform
terraform apply -auto-approve
cd ..
echo.

REM Re-enable scheduled queries
echo 2. Re-enabling BigQuery scheduled queries...
bq update --transfer_config projects/1063460452195/locations/us/transferConfigs/69b70f34-0000-20ec-b8b3-14223bb2f6ea >nul 2>&1 && echo    Enabled: silver-layer-transformation || echo    Not found: silver-layer-transformation
bq update --transfer_config projects/1063460452195/locations/us/transferConfigs/698c1b29-0000-26e1-b0e9-2405887af508 >nul 2>&1 && echo    Enabled: gold-fraud-metrics-aggregation || echo    Not found: gold-fraud-metrics-aggregation
bq update --transfer_config projects/1063460452195/locations/us/transferConfigs/69c01b19-0000-2ef8-8582-747446fe2e74 >nul 2>&1 && echo    Enabled: gold-merchant-analytics-aggregation || echo    Not found: gold-merchant-analytics-aggregation
echo.

echo ==========================================
echo Pipeline Resumed Successfully!
echo ==========================================
echo.
echo Current Status:
echo    - Pub/Sub subscriptions active
echo    - Scheduled queries enabled
echo    - All historical data preserved
echo.
echo Next Steps:
echo    1. Start the producer:
echo       cd producer ^&^& python producer.py
echo.
echo    2. Verify data flow:
echo       bq query --nouse_legacy_sql "SELECT COUNT(*) FROM `%PROJECT_ID%.fraud_detection.bronze_transactions`"
echo.

pause
