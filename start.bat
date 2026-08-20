@echo off
echo ============================================
echo  Salesforce ERP Demo - Quick Start
echo ============================================
echo.

REM 1. Start Mock ERP if not running
netstat -ano | findstr :3001 >nul 2>&1
if errorlevel 1 (
    echo [1/4] Starting Mock ERP server...
    start "Mock ERP" cmd /k "cd /d %~dp0mock-erp && npm start"
    timeout /t 3 /nobreak >nul
) else (
    echo [1/4] Mock ERP already running on port 3001
)

REM 2. Check Salesforce login
echo [2/4] Checking Salesforce CLI auth...
sf org list --all 2>nul | findstr /i "DevHub" >nul 2>&1
if errorlevel 1 (
    echo.
    echo  ACTION REQUIRED: Login to Salesforce Dev Hub
    echo  --------------------------------------------
    echo  A login window will open. In the browser:
    echo    1. Select Developer Edition org
    echo    2. Click Allow
    echo    3. Wait for "Authentication successful"
    echo.
    pause
    sf org login web --set-default-dev-hub --alias DevHub --browser chrome
)

REM 3. Deploy to scratch org
echo [3/4] Running setup (scratch org + deploy)...
cd /d %~dp0
powershell -ExecutionPolicy Bypass -File scripts\setup-local.ps1

REM 4. Open org
echo [4/4] Opening Salesforce org...
sf org open --target-org erp-demo

echo.
echo Done! Mock ERP: http://localhost:3001
pause
