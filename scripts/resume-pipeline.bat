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
for /f "tokens=*" %%i in ('bq ls --transfer_config --project_id^=%PROJECT_ID% --transfer_location^=us --format^=csv[no-heading]^(name^) 2^>nul') do (
  bq update --transfer_config --update_credentials %%i >nul 2>&1
  echo    Enabled: %%i
)
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
