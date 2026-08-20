@echo off
setlocal enabledelayedexpansion
echo ============================================
echo  Setup ngrok for Salesforce ERP Demo
echo ============================================
echo.

where ngrok >nul 2>&1
if errorlevel 1 (
    echo ERROR: ngrok not installed.
    echo Download: https://ngrok.com/download
    exit /b 1
)

if "%NGROK_AUTHTOKEN%"=="" (
    echo Get your authtoken from:
    echo   https://dashboard.ngrok.com/get-started/your-authtoken
    echo.
    set /p NGROK_AUTHTOKEN="Paste your ngrok authtoken here: "
)

if "!NGROK_AUTHTOKEN!"=="" (
    echo ERROR: No authtoken provided.
    exit /b 1
)

echo.
echo Configuring ngrok authtoken...
ngrok config add-authtoken !NGROK_AUTHTOKEN!
if errorlevel 1 (
    echo ERROR: Failed to configure authtoken.
    exit /b 1
)

echo.
echo Authtoken configured successfully!
echo.
echo Starting ngrok tunnel on port 3001...
echo Copy the HTTPS Forwarding URL shown below.
echo Example: https://xxxx.ngrok-free.app
echo.
echo Then update Salesforce:
echo   Setup -^> Custom Metadata Types -^> ERP Integration Setting
echo   API Base URL = https://YOUR-URL/api/v2.0
echo.
ngrok http 3001
