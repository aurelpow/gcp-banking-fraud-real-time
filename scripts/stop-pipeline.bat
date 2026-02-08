@echo off
REM Stop the streaming pipeline to save costs
REM This script disables scheduled queries and deletes Pub/Sub subscriptions
REM All data is preserved in BigQuery tables
REM 
REM NOTE: The transfer config IDs below are specific to your GCP project.
REM If these IDs don't work, get your config IDs with:
REM   bq ls --transfer_config --project_id=YOUR_PROJECT --transfer_location=us

setlocal enabledelayedexpansion

echo ==========================================
echo Stopping Real-Time Fraud Detection Pipeline
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

REM Stop scheduled queries
echo 1. Disabling BigQuery scheduled queries...
bq update --transfer_config --no_auto_scheduling projects/1063460452195/locations/us/transferConfigs/69b70f34-0000-20ec-b8b3-14223bb2f6ea >nul 2>&1 && echo    Disabled: silver-layer-transformation || echo    Not found: silver-layer-transformation
bq update --transfer_config --no_auto_scheduling projects/1063460452195/locations/us/transferConfigs/698c1b29-0000-26e1-b0e9-2405887af508 >nul 2>&1 && echo    Disabled: gold-fraud-metrics-aggregation || echo    Not found: gold-fraud-metrics-aggregation
bq update --transfer_config --no_auto_scheduling projects/1063460452195/locations/us/transferConfigs/69c01b19-0000-2ef8-8582-747446fe2e74 >nul 2>&1 && echo    Disabled: gold-merchant-analytics-aggregation || echo    Not found: gold-merchant-analytics-aggregation
echo.

REM Delete subscriptions
echo 2. Deleting Pub/Sub subscriptions...
gcloud pubsub subscriptions delete bq-bronze-subscription --quiet >nul 2>&1 && (
  echo    Deleted: bq-bronze-subscription
) || (
  echo    Already deleted: bq-bronze-subscription
)

gcloud pubsub subscriptions delete dead-letter-subscription --quiet >nul 2>&1 && (
  echo    Deleted: dead-letter-subscription
) || (
  echo    Already deleted: dead-letter-subscription
)
echo.

REM Check producer
echo 3. Checking for running producer...
tasklist /FI "IMAGENAME eq python.exe" 2>nul | find /i "python.exe" >nul
if %errorlevel% equ 0 (
  echo    WARNING: Python process running! Stop producer with Ctrl+C
) else (
  echo    No producer process running
)
echo.

echo ==========================================
echo Pipeline Stopped Successfully!
echo ==========================================
echo.
echo All data preserved in BigQuery tables:
echo    - bronze_transactions
echo    - silver_transactions
echo    - gold_fraud_metrics
echo    - gold_merchant_analytics
echo.
echo Remaining costs: ~$0.02-0.10/month (storage only)
echo.
echo To resume: Run scripts\resume-pipeline.bat
echo To fully delete: cd terraform ^&^& terraform destroy
echo.

pause
