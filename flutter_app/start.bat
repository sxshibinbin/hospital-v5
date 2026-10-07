@echo off
chcp 65001 >nul
title 启动AI医疗问诊系统 - Flutter Web

echo ========================================
echo   AI医疗问诊系统 - 移动端(Web版) 启动器
echo ========================================
echo.

REM 检查 Flutter SDK 路径
set FLUTTER_HOME=D:\flutter
if not exist "%FLUTTER_HOME%\bin\flutter.bat" (
    echo [错误] 未找到 Flutter SDK，请检查路径: %FLUTTER_HOME%
    pause
    exit /b 1
)

echo [1/3] 检查 Flutter 环境...
"%FLUTTER_HOME%\bin\flutter.bat" doctor --version >nul 2>&1
if errorlevel 1 (
    echo [警告] Flutter 环境检测失败，尝试继续...
) else (
    echo [成功] Flutter 环境正常
)

echo.
echo [2/3] 获取依赖...
"%FLUTTER_HOME%\bin\flutter.bat" pub get

echo.
echo [3/3] 启动 Flutter Web (Chrome)...
echo 应用将在 Chrome 浏览器中打开 (固定端口 5000)
echo 按 Ctrl+C 可停止应用
echo.
"%FLUTTER_HOME%\bin\flutter.bat" run -d chrome --web-port=5000
