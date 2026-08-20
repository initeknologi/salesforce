@echo off
echo ============================================
echo  Expose Mock ERP to Salesforce Cloud Org
echo ============================================
echo.
echo Mock ERP must already be running on port 3001.
echo This script uses ngrok to create a public URL.
echo.
echo Install ngrok: https://ngrok.com/download
echo.

where ngrok >nul 2>&1
if errorlevel 1 (
    echo ERROR: ngrok not found. Download from https://ngrok.com/download
    exit /b 1
)

echo Starting ngrok tunnel on port 3001...
echo.
echo After ngrok starts, copy the HTTPS URL (e.g. https://abc123.ngrok-free.app)
echo Then update in Salesforce:
echo   Setup -^> Custom Metadata Types -^> ERP Integration Setting -^> Local Development
echo   Set API Base URL to: https://YOUR-NGROK-URL/api/v2.0
echo.
echo Also add Remote Site in Setup:
echo   Setup -^> Remote Site Settings -^> New
echo   URL: https://YOUR-NGROK-URL
echo.
ngrok http 3001
