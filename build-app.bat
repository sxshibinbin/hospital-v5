@echo off
setlocal
chcp 65001 >nul

set "ROOT=%~dp0"
set "APP_DIR=%ROOT%flutter_app"

if not exist "%APP_DIR%\build-app.bat" (
    echo [ERROR] Cannot find Flutter APP build script:
    echo   %APP_DIR%\build-app.bat
    exit /b 1
)

call "%APP_DIR%\build-app.bat" %*
exit /b %ERRORLEVEL%
