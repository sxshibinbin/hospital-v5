@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul

REM ============================================================
REM  AI 医疗问诊系统 - Flutter App 启动管理脚本
REM  用法: start-flutter.bat [run|web|windows|apk|clean|pub|devices|doctor|help] [参数]
REM  默认: run (Chrome Web, 端口 5000)
REM ============================================================

REM ---- 定位 flutter_app 目录 ----
set "APP_DIR=%~dp0flutter_app"
if not exist "%APP_DIR%\pubspec.yaml" (
    set "APP_DIR=%~dp0"
)
if not exist "%APP_DIR%\pubspec.yaml" (
    echo [ERROR] 找不到 flutter_app 目录 pubspec.yaml
    echo         请将此脚本放在项目根目录下
    goto :end_error
)

cd /d "%APP_DIR%"

REM ---- 设置本地化环境变量 (隔离 SDK 缓存, 不污染系统) ----
set "FLUTTER_HOME=D:\flutter"
set "FLUTTER_BAT=%FLUTTER_HOME%\bin\flutter.bat"
set "APPDATA=%APP_DIR%\.dart_cli_home\AppData"
set "PUB_CACHE=%APP_DIR%\.pub-cache"
REM 重要: 必须使用 pub.dev (不要改用国内镜像), 因为 pubspec.lock 和
REM      package_config.json 中的包路径都指向 hosted/pub.dev 子目录,
REM      改用镜像 (如 pub.flutter-io.cn) 会导致包下载到另一个子目录, 路径不匹配
set "PUB_HOSTED_URL=https://pub.dev"

REM ---- 检查 Flutter SDK (默认路径优先, 失败则从 PATH 查找) ----
if not exist "%FLUTTER_BAT%" (
    for /f "delims=" %%i in ('where flutter.bat 2^>nul') do set "FLUTTER_BAT=%%i"
)
if not exist "%FLUTTER_BAT%" (
    echo [ERROR] 未找到 Flutter SDK
    echo        默认路径: %FLUTTER_HOME%\bin\flutter.bat
    echo        或将 flutter 加入系统 PATH
    goto :end_error
)

REM ---- 解析命令 ----
set "ACTION=run"
if not "%~1"=="" set "ACTION=%~1"

if /I "%ACTION%"=="run"     goto :cmd_run
if /I "%ACTION%"=="web"     goto :cmd_web
if /I "%ACTION%"=="windows" goto :cmd_windows
if /I "%ACTION%"=="apk"     goto :cmd_apk
if /I "%ACTION%"=="clean"   goto :cmd_clean
if /I "%ACTION%"=="pub"     goto :cmd_pub
if /I "%ACTION%"=="devices" goto :cmd_devices
if /I "%ACTION%"=="doctor"  goto :cmd_doctor
if /I "%ACTION%"=="help"    goto :show_help
if /I "%ACTION%"=="/?"      goto :show_help

echo [ERROR] 未知命令: %ACTION%
goto :show_help

REM ============ run [设备] (默认 chrome) ============
:cmd_run
set "DEVICE=%~2"
if "%DEVICE%"=="" set "DEVICE=chrome"
if /I "%DEVICE%"=="web" set "DEVICE=chrome"
if /I "%DEVICE%"=="chrome" goto :cmd_web
if /I "%DEVICE%"=="edge" goto :run_edge
if /I "%DEVICE%"=="windows" goto :cmd_windows
call :header 运行 Flutter - 设备 %DEVICE%
call :pub_get_if_needed
echo [RUN] flutter run -d %DEVICE%
echo       按 Ctrl+C 停止
echo.
"%FLUTTER_BAT%" run -d %DEVICE%
goto :end

:run_edge
call :header 运行 Flutter Web - Edge 端口 5000
call :pub_get_if_needed
call :check_port 5000
echo [RUN] flutter run -d edge --web-port=5000
echo       访问: http://localhost:5000
echo       按 Ctrl+C 停止
echo.
"%FLUTTER_BAT%" run -d edge --web-port=5000
goto :end

REM ============ web (Chrome, 端口 5000) ============
:cmd_web
call :header 运行 Flutter Web - Chrome 端口 5000
call :pub_get_if_needed
call :check_port 5000
echo [RUN] flutter run -d chrome --web-port=5000
echo       访问: http://localhost:5000
echo       按 Ctrl+C 停止
echo.
"%FLUTTER_BAT%" run -d chrome --web-port=5000
goto :end

REM ============ windows 桌面 ============
:cmd_windows
call :header 运行 Flutter Windows 桌面应用
call :pub_get_if_needed
echo [RUN] flutter run -d windows
echo       按 Ctrl+C 停止
echo.
"%FLUTTER_BAT%" run -d windows
goto :end

REM ============ apk [debug|release] ============
:cmd_apk
set "BUILD_MODE=%~2"
if "%BUILD_MODE%"=="" set "BUILD_MODE=release"
call :header 构建 APK - %BUILD_MODE%
if /I "%BUILD_MODE%"=="debug" (
    "%FLUTTER_BAT%" build apk --debug
    goto :apk_done
)
if /I "%BUILD_MODE%"=="release" (
    "%FLUTTER_BAT%" build apk --release
    goto :apk_done
)
echo [ERROR] 未知构建模式: %BUILD_MODE%
echo        可选: debug 或 release
goto :end_error
:apk_done
echo.
echo [OK] APK 构建完成
echo      输出目录: build\app\outputs\flutter-apk\
goto :end

REM ============ clean ============
:cmd_clean
call :header 清理构建缓存 flutter clean
"%FLUTTER_BAT%" clean
goto :end

REM ============ pub get ============
:cmd_pub
call :header 获取依赖 flutter pub get
"%FLUTTER_BAT%" pub get
goto :end

REM ============ devices ============
:cmd_devices
call :header 已连接设备列表
"%FLUTTER_BAT%" devices
goto :end

REM ============ doctor ============
:cmd_doctor
call :header Flutter 环境诊断
"%FLUTTER_BAT%" doctor
goto :end

REM ============ 子程序: 按需 pub get ============
:pub_get_if_needed
if not exist ".dart_tool\package_config.json" (
    echo [INFO] 首次运行, 获取依赖...
    "%FLUTTER_BAT%" pub get
    if errorlevel 1 (
        echo [ERROR] pub get 失败, 请检查网络或手动运行: flutter pub get
        goto :end_error
    )
    echo.
)
exit /b 0

REM ============ 子程序: 检查并释放端口 ============
:check_port
set "CHK_PORT=%~1"
if "%CHK_PORT%"=="" set "CHK_PORT=5000"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$p=%CHK_PORT%; $c=Get-NetTCPConnection -LocalPort $p -State Listen -ErrorAction SilentlyContinue; if($c){ $c | ForEach-Object { $procId=$_.OwningProcess; $pr=Get-Process -Id $procId -ErrorAction SilentlyContinue; if($pr){ Write-Host ('        停止占用端口 ' + $p + ' 的进程: ' + $pr.ProcessName + ' PID=' + $procId); Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue } }; Start-Sleep -Seconds 2; if(Get-NetTCPConnection -LocalPort $p -State Listen -ErrorAction SilentlyContinue){ Write-Host '[ERROR] 端口 ' + $p + ' 仍被占用'; exit 1 } }"
if errorlevel 1 (
    echo [ERROR] 端口 %CHK_PORT% 被占用且无法释放
    echo        请手动关闭占用该端口的程序后重试
    goto :end_error
)
exit /b 0

REM ============ 子程序: 标题 ============
:header
echo.
echo ========================================
echo   %~1
echo ========================================
echo.
exit /b 0

REM ============ 帮助 ============
:show_help
echo.
echo AI 医疗问诊系统 - Flutter App 启动管理脚本
echo.
echo 用法: start-flutter.bat [命令] [参数]
echo.
echo 命令:
echo   run [设备]    运行应用 (默认 chrome, 可选 edge/windows/设备ID)
echo   web           Web 模式 - Chrome 端口 5000
echo   windows       Windows 桌面应用
echo   apk [模式]    构建 APK (默认 release, 可选 debug)
echo   clean         清理构建缓存
echo   pub           获取依赖 flutter pub get
echo   devices       列出已连接设备
echo   doctor        Flutter 环境诊断
echo   help          显示此帮助
echo.
echo 示例:
echo   start-flutter.bat              运行 Chrome Web 端口 5000
echo   start-flutter.bat run windows  运行 Windows 桌面
echo   start-flutter.bat run edge     运行 Edge Web
echo   start-flutter.bat apk          构建 release APK
echo   start-flutter.bat apk debug    构建 debug APK
echo   start-flutter.bat devices      列出设备
echo.
goto :end

:end
echo.
endlocal
exit /b 0

:end_error
echo.
endlocal
exit /b 1
