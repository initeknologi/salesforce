@echo off
title ERP Tunnel Keep-Alive
echo ============================================
echo  ERP Tunnel Keep-Alive
echo  DO NOT CLOSE THIS WINDOW
echo ============================================
echo.
echo Mock ERP must run on port 3001 in another terminal.
echo Tunnel will auto-restart if it disconnects.
echo.

:loop
echo [%date% %time%] Starting localtunnel...
for /f "delims=" %%i in ('npx --yes localtunnel --port 3001 2^>^&1 ^| findstr "your url is:"') do set LINE=%%i
echo %%LINE%%
echo.
echo IMPORTANT: If URL changed, update Salesforce Custom Metadata:
echo   Setup -^> Custom Metadata Types -^> ERP Integration Setting
echo   API Base URL = https://NEW-URL/api/v2.0
echo.
echo Press Ctrl+C to stop.
timeout /t 300 /nobreak
goto loop
