@echo off
chcp 65001 >nul
title 启动AI医疗问诊系统 - 后端服务

echo ========================================
echo   AI医疗问诊系统 - 后端服务启动器
echo ========================================
echo.

REM 检查 Python 环境
python --version >nul 2>&1
if errorlevel 1 (
    echo [错误] 未找到 Python，请确保已安装 Python 3.11+ 并添加到 PATH
    pause
    exit /b 1
)

echo [1/2] 检查 Python 环境...
python --version
echo [成功] Python 环境正常

echo.
echo [2/2] 启动后端服务 (端口 8000)...
echo 后端将在 http://localhost:8000 运行
echo 按 Ctrl+C 可停止服务
echo.

cd /d "%~dp0..\backend"
python run.py
