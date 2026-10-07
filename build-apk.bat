@echo off
setlocal EnableExtensions EnableDelayedExpansion

set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"

set "FLUTTER_HOME=D:\sdk\flutter"
set "FLUTTER_APP=%ROOT%\flutter_app"
set "ANDROID_DIR=%FLUTTER_APP%\android"
set "DIST_DIR=%ROOT%\dist"
set "APK_NAME=hospital-v5-android-release.apk"
set "SRC_APK=%FLUTTER_APP%\build\app\outputs\flutter-apk\app-release.apk"
set "DIST_APK=%DIST_DIR%\%APK_NAME%"
set "ALIYUN_AUTH_FILE=%FLUTTER_APP%\ohos\aliyun-number-auth.local.properties"
set "API_PORT=8000"

if /I "%~1"=="help" goto usage
if /I "%~1"=="-h" goto usage
if /I "%~1"=="--help" goto usage
if not "%~2"=="" set "API_PORT=%~2"

call :resolve_api_url "%~1"
if errorlevel 1 exit /b 1
call :normalize_api_url

set "APPDATA=%ROOT%\.dart_cli_home"
set "LOCALAPPDATA=%ROOT%\.dart_cli_home"
set "GRADLE_USER_HOME=%FLUTTER_APP%\.gradle_home"
set "ANDROID_HOME=D:\sdk\android-sdk"
set "ANDROID_SDK_ROOT=D:\sdk\android-sdk"
set "JAVA_HOME=C:\Program Files\Java\jdk-17.0.12"
set "PUB_CACHE=%FLUTTER_APP%\.pub-cache"
set "FLUTTER_ROOT=%FLUTTER_HOME%"
set "FLUTTER_SUPPRESS_ANALYTICS=true"
set "FLUTTER_STORAGE_BASE_URL=https://storage.googleapis.com"

call :check_required_paths
if errorlevel 1 exit /b 1
call :write_local_properties
if errorlevel 1 exit /b 1

for /f "usebackq delims=" %%D in (`powershell -NoProfile -ExecutionPolicy Bypass -Command "$defines = New-Object System.Collections.Generic.List[string]; $defines.Add('API_BASE_URL=' + $env:API_BASE_URL); $keyFile = $env:ALIYUN_AUTH_FILE; if (Test-Path -LiteralPath $keyFile) { foreach ($line in [IO.File]::ReadAllLines($keyFile, [Text.Encoding]::UTF8)) { if ($line -match '^\s*ALIYUN_NUMBER_AUTH_ANDROID_SK\s*=(.*)$') { $sk = $Matches[1].Trim(); if ($sk) { $defines.Add('ALIYUN_NUMBER_AUTH_ANDROID_SK=' + $sk) }; break } } }; $encoded = foreach ($item in $defines) { [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($item)) }; [string]::Join(',', $encoded)"`) do set "DART_DEFINE=%%D"

if not defined DART_DEFINE (
    echo [ERROR] Failed to generate dart-defines.
    exit /b 1
)

echo.
echo ========================================
echo   Hospital V5 Android APK Build
echo ========================================
echo Root:      %ROOT%
echo API URL:   %API_BASE_URL%
if exist "%ALIYUN_AUTH_FILE%" (
    echo Aliyun:   local number auth config found
) else (
    echo Aliyun:   local number auth config not found, one-click login disabled
)
echo Flutter:   %FLUTTER_HOME%
echo SDK:       %ANDROID_HOME%
echo Gradle:    %GRADLE_USER_HOME%
echo Output:    %DIST_APK%
echo.

call :check_backend

echo.
echo [1/4] Preparing Android Flutter cache...
call :sync_flutter_package_config
if errorlevel 1 exit /b 1
call :sync_flutter_plugins_dependencies
if errorlevel 1 exit /b 1

echo.
echo [2/4] Building release APK...
pushd "%ANDROID_DIR%"
call gradlew.bat --no-daemon --no-watch-fs --no-configuration-cache --no-build-cache :app:assembleRelease -Pdart-defines=%DART_DEFINE% --console=plain --stacktrace
set "BUILD_EXIT=%ERRORLEVEL%"
popd

if not "%BUILD_EXIT%"=="0" (
    echo.
    echo [ERROR] APK build failed. Exit code: %BUILD_EXIT%
    exit /b %BUILD_EXIT%
)

if not exist "%SRC_APK%" (
    echo.
    echo [ERROR] Build completed but APK was not found:
    echo %SRC_APK%
    exit /b 1
)

echo.
echo [3/4] Copying APK to dist...
if not exist "%DIST_DIR%" mkdir "%DIST_DIR%"
copy /Y "%SRC_APK%" "%DIST_APK%" >nul
if errorlevel 1 (
    echo [ERROR] Failed to copy APK to dist.
    exit /b 1
)

echo.
echo [4/4] Verifying APK...
if exist "%ANDROID_HOME%\build-tools\36.0.0\apksigner.bat" (
    "%ANDROID_HOME%\build-tools\36.0.0\apksigner.bat" verify --verbose --print-certs "%DIST_APK%"
) else (
    echo [WARN] apksigner not found, signature verification skipped.
)

if exist "%ANDROID_HOME%\build-tools\36.0.0\aapt.exe" (
    "%ANDROID_HOME%\build-tools\36.0.0\aapt.exe" dump badging "%DIST_APK%" | findstr /C:"package:" /C:"sdkVersion" /C:"targetSdkVersion" /C:"application-label:"
) else (
    echo [WARN] aapt not found, package info verification skipped.
)

echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-Item -LiteralPath $env:DIST_APK | Select-Object FullName,Length,LastWriteTime; Get-FileHash -LiteralPath $env:DIST_APK -Algorithm SHA256 | Select-Object Algorithm,Hash"

echo.
echo [OK] APK build completed:
echo %DIST_APK%
echo.
echo Install this APK on the phone and keep the phone and backend PC on the same network.
exit /b 0

:resolve_api_url
set "INPUT_URL=%~1"
if not "%INPUT_URL%"=="" (
    set "API_BASE_URL=%INPUT_URL%"
    if /I not "!API_BASE_URL:~0,7!"=="http://" if /I not "!API_BASE_URL:~0,8!"=="https://" (
        echo(!API_BASE_URL! | findstr ":" >nul
        if errorlevel 1 (
            set "API_BASE_URL=http://!API_BASE_URL!:%API_PORT%"
        ) else (
            set "API_BASE_URL=http://!API_BASE_URL!"
        )
    )
    exit /b 0
)

set "HOST_IP="
for /f "tokens=2 delims=:" %%I in ('ipconfig ^| findstr /R /C:"IPv4"') do (
    if not defined HOST_IP (
        set "CANDIDATE=%%I"
        set "CANDIDATE=!CANDIDATE: =!"
        if not "!CANDIDATE:~0,4!"=="127." if not "!CANDIDATE:~0,8!"=="169.254." if not "!CANDIDATE:~0,7!"=="172.24." (
            set "HOST_IP=!CANDIDATE!"
        )
    )
)

if not defined HOST_IP (
    echo [WARN] Failed to auto-detect backend PC IPv4.
    set /p "HOST_IP=Enter backend PC IPv4, for example 172.19.51.96: "
)

if not defined HOST_IP (
    echo [ERROR] API host IP is required.
    exit /b 1
)

set "API_BASE_URL=http://%HOST_IP%:%API_PORT%"
exit /b 0

:normalize_api_url
if defined API_BASE_URL (
    if "!API_BASE_URL:~-1!"=="/" if not "!API_BASE_URL:~-3!"=="://" (
        set "API_BASE_URL=!API_BASE_URL:~0,-1!"
        goto normalize_api_url
    )
)
exit /b 0

:check_required_paths
if not exist "%FLUTTER_HOME%\bin\flutter.bat" (
    echo [ERROR] Flutter SDK not found: %FLUTTER_HOME%
    exit /b 1
)

if not exist "%JAVA_HOME%\bin\java.exe" (
    echo [ERROR] JDK not found: %JAVA_HOME%
    exit /b 1
)

if not exist "%ANDROID_HOME%\platform-tools" (
    echo [ERROR] Android SDK not found: %ANDROID_HOME%
    exit /b 1
)

if not exist "%ANDROID_DIR%\gradlew.bat" (
    echo [ERROR] Gradle wrapper not found: %ANDROID_DIR%\gradlew.bat
    exit /b 1
)

exit /b 0

:write_local_properties
powershell -NoProfile -ExecutionPolicy Bypass -Command "$path = Join-Path $env:ANDROID_DIR 'local.properties'; $flutterSdk = $env:FLUTTER_HOME.Replace('\', '\\'); $androidSdk = $env:ANDROID_HOME.Replace('\', '\\'); $nl = [Environment]::NewLine; $content = 'flutter.sdk=' + $flutterSdk + $nl + 'sdk.dir=' + $androidSdk + $nl + 'flutter.buildMode=release' + $nl + 'flutter.versionName=1.0.0' + $nl + 'flutter.versionCode=1' + $nl; [IO.File]::WriteAllText($path, $content, [System.Text.UTF8Encoding]::new($false))"
if errorlevel 1 (
    echo [ERROR] Failed to write Android local.properties.
    exit /b 1
)
exit /b 0

:sync_flutter_package_config
set "PACKAGE_CONFIG=%FLUTTER_APP%\.dart_tool\package_config.json"
if not exist "%PACKAGE_CONFIG%" (
    echo [INFO] package_config.json not found, running flutter pub get.
    pushd "%FLUTTER_APP%"
    call "%FLUTTER_HOME%\bin\flutter.bat" pub get
    set "PUB_EXIT=%ERRORLEVEL%"
    popd
    if not "!PUB_EXIT!"=="0" (
        echo [ERROR] Flutter pub get failed. Exit code: !PUB_EXIT!
        exit /b !PUB_EXIT!
    )
    exit /b 0
)

powershell -NoProfile -ExecutionPolicy Bypass -Command "$cfg = $env:PACKAGE_CONFIG; $flutterUri = 'file:///' + $env:FLUTTER_HOME.Replace('\', '/'); $pubCache = $env:PUB_CACHE; $json = Get-Content -LiteralPath $cfg -Raw -Encoding UTF8 | ConvertFrom-Json; $changed = $false; if ($json.flutterRoot -ne $flutterUri) { $json.flutterRoot = $flutterUri; $changed = $true }; foreach ($pkg in $json.packages) { $target = $null; switch ($pkg.name) { 'flutter' { $target = $flutterUri + '/packages/flutter' } 'flutter_test' { $target = $flutterUri + '/packages/flutter_test' } 'flutter_web_plugins' { $target = $flutterUri + '/packages/flutter_web_plugins' } 'sky_engine' { $target = $flutterUri + '/bin/cache/pkg/sky_engine' } }; if (-not $target -and $pkg.rootUri -like 'file:///C:/Users/*/Pub/Cache/hosted/*/*') { $uri = [Uri]$pkg.rootUri; $packageDir = Split-Path -Leaf $uri.LocalPath; $cacheHost = Split-Path -Leaf (Split-Path -Parent $uri.LocalPath); foreach ($candidateHost in @($cacheHost, 'pub.dev', 'pub.flutter-io.cn')) { $candidate = Join-Path (Join-Path (Join-Path $pubCache 'hosted') $candidateHost) $packageDir; if (Test-Path -LiteralPath $candidate) { $target = 'file:///' + $candidate.Replace('\', '/'); break } } }; if ($target -and $pkg.rootUri -ne $target) { $pkg.rootUri = $target; $changed = $true } }; if ($changed) { [IO.File]::WriteAllText($cfg, (($json | ConvertTo-Json -Depth 100) + [Environment]::NewLine), [System.Text.UTF8Encoding]::new($false)); Write-Host '[OK] package_config.json Flutter/package cache paths updated.' } else { Write-Host '[OK] package_config.json already uses Android Flutter SDK and local package cache.' }"
if errorlevel 1 (
    echo [ERROR] Failed to sync package_config.json Flutter SDK paths.
    exit /b 1
)
exit /b 0

:sync_flutter_plugins_dependencies
set "PLUGIN_DEPS=%FLUTTER_APP%\.flutter-plugins-dependencies"
if not exist "%PLUGIN_DEPS%" (
    echo [INFO] .flutter-plugins-dependencies not found, skipping plugin cache path sync.
    exit /b 0
)

powershell -NoProfile -ExecutionPolicy Bypass -Command "$path = $env:PLUGIN_DEPS; $pubCache = $env:PUB_CACHE; $json = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json; $changed = $false; foreach ($platform in $json.plugins.PSObject.Properties) { foreach ($plugin in @($platform.Value)) { $old = [string]$plugin.path; if (-not $old) { continue }; $trim = ($old -replace '/', '\') -replace '\\+$', ''; $parts = $trim -split '\\+'; $hostedIndex = [Array]::IndexOf($parts, 'hosted'); if ($hostedIndex -lt 0 -or $parts.Length -le ($hostedIndex + 2)) { continue }; $cacheHost = $parts[$hostedIndex + 1]; $packageDir = $parts[$hostedIndex + 2]; foreach ($candidateHost in @($cacheHost, 'pub.dev', 'pub.flutter-io.cn')) { $candidate = Join-Path (Join-Path (Join-Path $pubCache 'hosted') $candidateHost) $packageDir; if (Test-Path -LiteralPath $candidate) { $target = $candidate.TrimEnd('\') + '\'; if ($plugin.path -ne $target) { $plugin.path = $target; $changed = $true }; break } } } }; if ($changed) { [IO.File]::WriteAllText($path, (($json | ConvertTo-Json -Depth 100 -Compress) + [Environment]::NewLine), [System.Text.UTF8Encoding]::new($false)); Write-Host '[OK] .flutter-plugins-dependencies package cache paths updated.' } else { Write-Host '[OK] .flutter-plugins-dependencies already uses local package cache.' }"
if errorlevel 1 (
    echo [ERROR] Failed to sync .flutter-plugins-dependencies package cache paths.
    exit /b 1
)
exit /b 0

:check_backend
echo Checking backend: %API_BASE_URL%/docs
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { $r = Invoke-WebRequest -Uri ($env:API_BASE_URL + '/docs') -UseBasicParsing -TimeoutSec 5; if ($r.StatusCode -ge 200 -and $r.StatusCode -lt 500) { exit 0 }; exit 1 } catch { exit 1 }"
if errorlevel 1 (
    echo [WARN] Backend check failed from this PC.
    echo [WARN] Build will continue, but the phone may still fail if backend, network, or firewall is blocked.
) else (
    echo [OK] Backend is reachable from this PC.
)
exit /b 0

:usage
echo Usage:
echo   build-apk.bat
echo   build-apk.bat 172.19.51.96
echo   build-apk.bat 172.19.51.96 8000
echo   build-apk.bat http://172.19.51.96:8000
echo   build-apk.bat https://web.sstkjgf.com
echo.
echo No argument: auto-detect IPv4 and build with http://IP:8000.
exit /b 0
