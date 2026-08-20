@echo off
echo ============================================
echo  ERP Integration Demo - Start Services
echo ============================================
echo.

netstat -ano | findstr :3001 >nul 2>&1
if errorlevel 1 (
    echo [1/2] Starting Mock ERP on port 3001...
    start "Mock ERP" cmd /k "cd /d %~dp0mock-erp && npm start"
    timeout /t 3 /nobreak >nul
) else (
    echo [1/2] Mock ERP already running on port 3001
)

echo [2/2] Starting localtunnel (public URL for Salesforce)...
echo.
echo IMPORTANT: Copy the HTTPS URL shown below (e.g. https://xxx.loca.lt)
echo Then update Salesforce Custom Metadata if URL changed:
echo   Setup -^> Custom Metadata Types -^> ERP Integration Setting -^> Local Development
echo   API Base URL = https://YOUR-URL/api/v2.0
echo.
start "Localtunnel" cmd /k "npx --yes localtunnel --port 3001"

echo.
echo Done! Keep both windows open while using Salesforce.
pause
