@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul

REM ============================================================
REM  AI 医疗问诊系统 - Backend 启动管理脚本
REM  用法: start-backend.bat [start|stop|restart|status|log|dev|help] [port]
REM  默认: start  端口: 8000
REM ============================================================

REM ---- 自动定位 backend 目录（脚本可放在项目根或任意位置）----
set "BACKEND_DIR=%~dp0backend"
if not exist "%BACKEND_DIR%\main.py" (
    set "BACKEND_DIR=%~dp0"
)
if not exist "%BACKEND_DIR%\main.py" (
    echo [ERROR] 找不到 backend 目录 main.py
    echo         请将此脚本放在项目根目录下
    goto :end_error
)

cd /d "%BACKEND_DIR%"

set "PYTHON_EXE=%BACKEND_DIR%\.venv\Scripts\python.exe"
set "PORT=8000"
set "PID_FILE=%BACKEND_DIR%\.server.pid"
set "LOG_POINTER=%BACKEND_DIR%\.server.log"
set "LOG_DIR=%BACKEND_DIR%\logs"
set "START_WAIT_SECONDS=15"
set "STOP_WAIT_SECONDS=10"

REM ---- 解析命令 ----
set "ACTION=start"
if not "%~1"=="" set "ACTION=%~1"
if /I "%~2" NEQ "" set "PORT=%~2"

if /I "%ACTION%"=="help"  goto :show_help
if /I "%ACTION%"=="-h"    goto :show_help
if /I "%ACTION%"=="/?"    goto :show_help
if /I "%ACTION%"=="start"   goto :check_env
if /I "%ACTION%"=="dev"     goto :check_env_dev
if /I "%ACTION%"=="stop"    goto :stop
if /I "%ACTION%"=="restart" goto :restart
if /I "%ACTION%"=="status"  goto :status
if /I "%ACTION%"=="log"     goto :show_log

echo [ERROR] 未知命令: %ACTION%
goto :show_help

REM ============ 环境检查 ============
:check_env
call :check_python
if errorlevel 1 goto :end_error
if not exist "%BACKEND_DIR%\.env" (
    echo [WARN] 未找到 .env 配置文件，将使用默认环境变量
    echo        参考 .env.example 进行配置
)
goto :check_and_start

:check_env_dev
call :check_python
if errorlevel 1 goto :end_error
if not exist "%BACKEND_DIR%\.env" (
    echo [WARN] 未找到 .env 配置文件
)
goto :dev_mode

REM ============ 开发模式 (前台 + 热重载) ============
:dev_mode
echo.
echo [DEV] 开发模式启动 (前台运行, 热重载)
echo       端口: %PORT%
echo       按 Ctrl+C 停止
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command "$envFile='%BACKEND_DIR%\.env'; if (Test-Path $envFile) { Get-Content $envFile | ForEach-Object { if ($_ -match '^\s*([^#=]+)=(.*)$') { [Environment]::SetEnvironmentVariable($Matches[1].Trim(), $Matches[2].Trim(), 'Process') } } }; & '%PYTHON_EXE%' -m uvicorn main:app --reload --host 0.0.0.0 --port %PORT%"
goto :end

REM ============ 生产模式 (后台运行) ============
:check_and_start
call :stop_old

:start_after_stop
call :wait_port_free
if errorlevel 1 (
    echo [ERROR] 端口 %PORT% 仍被占用，启动失败
    goto :end_error
)

if not exist "%LOG_DIR%" mkdir "%LOG_DIR%" >nul 2>&1
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd-HHmmss-fff"') do set "STAMP=%%i"
set "LOG_FILE=%LOG_DIR%\server-%PORT%-%STAMP%.log"

echo.
echo [INFO] 启动 FastAPI 服务 (生产模式, 后台运行)
echo        端口: %PORT%
echo        日志: %LOG_FILE%
echo.

call :start_server_process
if errorlevel 1 (
    echo [ERROR] 进程启动失败，请查看日志: %LOG_FILE%
    goto :end_error
)
echo %LOG_FILE%>"%LOG_POINTER%"

call :wait_port_listening
if not errorlevel 1 (
    call :write_listen_pid
    echo [OK] 服务已启动: http://localhost:%PORT%
    echo      健康检查:   http://localhost:%PORT%/api/health
    echo      日志文件:   %LOG_FILE%
    echo      查看日志:   start-backend.bat log
    echo      停止服务:   start-backend.bat stop
) else (
    echo [WARN] 服务可能未启动成功，请查看日志: %LOG_FILE%
)
goto :end

REM ============ 停止 ============
:stop
echo [INFO] 停止服务 (端口: %PORT%)...
call :stop_old
call :is_port_listening
if not errorlevel 1 (
    echo [WARN] 端口 %PORT% 仍被占用
) else (
    echo [OK] 服务已停止
)
goto :end

REM ============ 重启 ============
:restart
echo [INFO] 重启服务...
call :stop_old
call :sleep 1
goto :start_after_stop

REM ============ 状态 ============
:status
call :is_port_listening
if not errorlevel 1 (
    echo [OK] 服务运行中
    echo      端口: %PORT%
    if exist "%PID_FILE%" (
        set /p PID=<"%PID_FILE%"
        echo      PID:  !PID!
    )
    if exist "%LOG_POINTER%" (
        set /p CURRENT_LOG=<"%LOG_POINTER%"
        echo      日志: !CURRENT_LOG!
    )
) else (
    echo [INFO] 服务未运行
)
goto :end

REM ============ 查看日志 ============
:show_log
set "CURRENT_LOG="
if exist "%LOG_POINTER%" set /p CURRENT_LOG=<"%LOG_POINTER%"
if not defined CURRENT_LOG if exist "%LOG_DIR%" (
    for /f "delims=" %%f in ('dir /b /o-d "%LOG_DIR%\server-*.log" 2^>nul') do (
        set "CURRENT_LOG=%LOG_DIR%\%%f"
        goto :found_log
    )
)
:found_log
if not defined CURRENT_LOG (
    echo [ERROR] 未找到日志文件
    goto :end_error
)
echo [INFO] 实时日志 (Ctrl+C 退出): !CURRENT_LOG!
echo.
powershell -NoProfile -Command "Get-Content -LiteralPath '!CURRENT_LOG!' -Wait -Tail 50 -Encoding UTF8"
goto :end

REM ============ 显示帮助 ============
:show_help
echo.
echo AI 医疗问诊系统 - Backend 启动管理脚本
echo.
echo 用法: start-backend.bat [命令] [端口]
echo.
echo 命令:
echo   start     后台启动服务 (默认)
echo   dev       前台启动 + 热重载 (开发模式)
echo   stop      停止服务
echo   restart   重启服务
echo   status    查看运行状态
echo   log       实时查看日志
echo   help      显示此帮助
echo.
echo 示例:
echo   start-backend.bat              启动 (默认端口 8000)
echo   start-backend.bat start 8080   在 8080 端口启动
echo   start-backend.bat dev          开发模式 (热重载)
echo   start-backend.bat stop         停止
echo   start-backend.bat log          查看日志
echo.
goto :end

REM ============================================================
REM  以下为内部子程序
REM ============================================================

:check_python
if not exist "%PYTHON_EXE%" (
    echo [ERROR] 未找到虚拟环境: %PYTHON_EXE%
    echo         请先创建虚拟环境:
    echo           cd backend
    echo           python -m venv .venv
    echo           .venv\Scripts\activate
    echo           pip install -r requirements.txt
    exit /b 1
)
exit /b 0

:stop_old
set "FOUND_PROCESS="

if exist "%PID_FILE%" (
    set /p OLD_PID=<"%PID_FILE%"
    tasklist /FI "PID eq !OLD_PID!" 2>nul | findstr "!OLD_PID!" >nul
    if not errorlevel 1 (
        echo        停止旧进程 PID: !OLD_PID! ...
        call :kill_process_tree !OLD_PID!
        set "FOUND_PROCESS=1"
    )
    del "%PID_FILE%" >nul 2>&1
)

for /f "tokens=*" %%a in ('powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { ($_.Name -match '^(python|python3|uvicorn)') -and ($_.CommandLine -match 'uvicorn') -and ($_.CommandLine -match 'main:app') -and ($_.CommandLine -match '--port\s+%PORT%') } | ForEach-Object { $_.ProcessId }" 2^>nul') do (
    if not "%%a"=="" (
        echo        停止 uvicorn 进程 PID: %%a ...
        call :kill_process_tree %%a
        set "FOUND_PROCESS=1"
    )
)

call :is_port_listening
if not errorlevel 1 (
    if not defined FOUND_PROCESS echo        端口 %PORT% 被占用，释放中...
    for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":%PORT% " ^| findstr "LISTENING"') do (
        call :kill_process_tree %%a
        set "FOUND_PROCESS=1"
    )
)

if defined FOUND_PROCESS call :wait_port_free
exit /b 0

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
powershell -NoProfile -ExecutionPolicy Bypass -Command "$envFile='%BACKEND_DIR%\.env'; if (Test-Path $envFile) { Get-Content $envFile | ForEach-Object { if ($_ -match '^\s*([^#=]+)=(.*)$') { [Environment]::SetEnvironmentVariable($Matches[1].Trim(), $Matches[2].Trim(), 'Process') } } }; $p = Start-Process -FilePath 'cmd.exe' -ArgumentList @('/d','/s','/c','%PYTHON_EXE% run.py > %LOG_FILE% 2>&1') -WorkingDirectory '%BACKEND_DIR%' -WindowStyle Hidden -PassThru; Set-Content -LiteralPath '%PID_FILE%' -Value $p.Id"
exit /b %errorlevel%

:sleep
powershell -NoProfile -Command "Start-Sleep -Seconds %~1" >nul 2>&1
exit /b 0

:end
echo.
endlocal
exit /b 0

:end_error
echo.
endlocal
exit /b 1
