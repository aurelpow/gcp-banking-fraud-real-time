@echo off
REM Stop the streaming pipeline to save costs
REM This script disables scheduled queries and deletes Pub/Sub subscriptions
REM All data is preserved in BigQuery tables

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
for /f "tokens=*" %%i in ('bq ls --transfer_config --project_id^=%PROJECT_ID% --transfer_location^=us --format^=json 2^>nul') do set CONFIGS=%%i
if "%CONFIGS%"=="[]" (
  echo    No scheduled queries found
) else (
  for /f "tokens=*" %%i in ('bq ls --transfer_config --project_id^=%PROJECT_ID% --transfer_location^=us --format^=csv[no-heading]^(name^) 2^>nul') do (
    bq update --transfer_config --no_auto_scheduling %%i >nul 2>&1
    echo    Disabled: %%i
  )
)
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
