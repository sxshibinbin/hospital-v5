@echo off
chcp 65001 >nul
title 启动AI医疗问诊系统 - 完整启动

echo ========================================
echo   AI医疗问诊系统 - 完整启动器
echo ========================================
echo.

REM 检查 Python 环境
python --version >nul 2>&1
if errorlevel 1 (
    echo [错误] 未找到 Python，请确保已安装 Python 3.11+ 并添加到 PATH
    pause
    exit /b 1
)

REM 检查 Flutter SDK
set FLUTTER_HOME=D:\flutter
if not exist "%FLUTTER_HOME%\bin\flutter.bat" (
    echo [错误] 未找到 Flutter SDK，请检查路径: %FLUTTER_HOME%
    pause
    exit /b 1
)

echo [1/4] 检查环境...
python --version
echo Flutter SDK: %FLUTTER_HOME%
echo.

echo [2/4] 启动后端服务...
start "后端服务" cmd /k "cd /d %~dp0..\backend && python run.py"
timeout /t 3 /nobreak >nul
echo [成功] 后端服务已启动 (端口 8000)
echo.

echo [3/4] 检查后端状态...
curl -s -o /dev/null -w "HTTP状态码: %%{http_code}\n" http://localhost:8000/api/health
echo.

echo [4/4] 启动 Flutter Web (Chrome)...
echo 应用将在 Chrome 浏览器中打开 (固定端口 5000)
echo.
"%FLUTTER_HOME%\bin\flutter.bat" run -d chrome --web-port=5000

echo.
echo ========================================
echo   启动完成！
echo   后端: http://localhost:8000
echo   前端: Chrome 浏览器中查看
echo ========================================
pause
