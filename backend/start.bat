@echo off
setlocal enabledelayedexpansion

set "PORT=8000"
set "PID_FILE=.server.pid"
set "LOG_POINTER=.server.log"
set "LOG_DIR=logs"
set "START_WAIT_SECONDS=15"
set "STOP_WAIT_SECONDS=10"

if /I "%~1"=="stop" goto :stop
if /I "%~1"=="restart" goto :restart
if /I "%~1"=="status" goto :status
if not "%~1"=="" set "PORT=%~1"

goto :check_and_start

:check_and_start
call :stop_old

:start_after_stop
call :wait_port_free
if errorlevel 1 (
    echo [ERROR] Port %PORT% is still in use. Server not started.
    goto :end
)

if not exist "%LOG_DIR%" mkdir "%LOG_DIR%" >nul 2>&1
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd-HHmmss-fff"') do set "STAMP=%%i"
set "LOG_FILE=%LOG_DIR%\server-%PORT%-%STAMP%.log"

echo.
echo Starting FastAPI on port %PORT% ...
echo.

call :start_server_process
if errorlevel 1 (
    echo [ERROR] Failed to start server process. Check %LOG_FILE%
    goto :end
)
echo %LOG_FILE%>"%LOG_POINTER%"

call :wait_port_listening
if not errorlevel 1 (
    call :write_listen_pid
    echo [OK] Server started on http://localhost:%PORT%
    echo       Log: %LOG_FILE%
) else (
    echo [WARN] Server may not have started. Check %LOG_FILE%
)
goto :end

:stop_old
set "FOUND_PROCESS="

if exist "%PID_FILE%" (
    set /p OLD_PID=<"%PID_FILE%"
    tasklist /FI "PID eq !OLD_PID!" 2>nul | findstr "!OLD_PID!" >nul
    if not errorlevel 1 (
        echo Stopping old server ^(PID: !OLD_PID!^)...
        call :kill_process_tree !OLD_PID!
        set "FOUND_PROCESS=1"
    )
    del "%PID_FILE%" >nul 2>&1
)

for /f "tokens=*" %%a in ('powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { ($_.Name -match '^(python|python3|uvicorn)') -and ($_.CommandLine -match 'uvicorn') -and ($_.CommandLine -match 'main:app') -and ($_.CommandLine -match '--port\s+%PORT%') } | ForEach-Object { $_.ProcessId }" 2^>nul') do (
    if not "%%a"=="" (
        echo Stopping uvicorn process ^(PID: %%a^)...
        call :kill_process_tree %%a
        set "FOUND_PROCESS=1"
    )
)

call :is_port_listening
if not errorlevel 1 (
    if not defined FOUND_PROCESS echo Port %PORT% is in use, releasing...
    for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":%PORT% " ^| findstr "LISTENING"') do (
        call :kill_process_tree %%a
        set "FOUND_PROCESS=1"
    )
)

if defined FOUND_PROCESS call :wait_port_free
exit /b 0

:stop
echo Stopping server...
call :stop_old
call :is_port_listening
if not errorlevel 1 (
    echo [WARN] Port %PORT% is still in use
) else (
    echo [OK] Stopped server on port %PORT%
)
goto :end

:restart
echo Stopping server...
call :stop_old
call :sleep 1
goto :start_after_stop

:status
call :is_port_listening
if not errorlevel 1 (
    echo [OK] Server is running
    echo   Port: %PORT%
    if exist "%PID_FILE%" (
        set /p PID=<"%PID_FILE%"
        echo   PID: !PID!
    )
    if exist "%LOG_POINTER%" (
        set /p CURRENT_LOG=<"%LOG_POINTER%"
        echo   Log: !CURRENT_LOG!
    )
) else (
    echo Server is not running
)
goto :end

:is_port_listening
netstat -an | findstr ":%PORT% " | findstr "LISTENING" >nul
exit /b %errorlevel%

:wait_port_free
for /l %%i in (1,1,%STOP_WAIT_SECONDS%) do (
    call :is_port_listening
    if errorlevel 1 exit /b 0
    call :sleep 1
)
exit /b 1

:wait_port_listening
for /l %%i in (1,1,%START_WAIT_SECONDS%) do (
    call :is_port_listening
    if not errorlevel 1 exit /b 0
    call :sleep 1
)
exit /b 1

:write_listen_pid
if exist "%PID_FILE%" exit /b 0
set "LISTEN_PID="
for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":%PORT% " ^| findstr "LISTENING"') do (
    if not defined LISTEN_PID set "LISTEN_PID=%%a"
)
if not defined LISTEN_PID exit /b 0
for /f %%a in ('tasklist /FI "PID eq !LISTEN_PID!" 2^>nul ^| findstr "!LISTEN_PID!"') do (
    echo !LISTEN_PID!>"%PID_FILE%"
)
exit /b 0

:kill_process_tree
set "TARGET_PID=%~1"
if "%TARGET_PID%"=="" exit /b 0
taskkill /PID %TARGET_PID% /T /F >nul 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { $_.ParentProcessId -eq %TARGET_PID% } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }" >nul 2>&1
exit /b 0

:start_server_process
powershell -NoProfile -ExecutionPolicy Bypass -Command "$cmd = 'uvicorn main:app --reload --host 0.0.0.0 --port %PORT% > %LOG_FILE% 2>&1'; $p = Start-Process -FilePath 'cmd.exe' -ArgumentList @('/d','/s','/c',$cmd) -WorkingDirectory (Get-Location).Path -WindowStyle Hidden -PassThru; Set-Content -LiteralPath '%PID_FILE%' -Value $p.Id"
exit /b %errorlevel%

:sleep
powershell -NoProfile -Command "Start-Sleep -Seconds %~1" >nul 2>&1
exit /b 0

:end
echo.
endlocal
exit /b 0
