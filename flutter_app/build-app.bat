@echo off
setlocal EnableExtensions
chcp 65001 >nul

set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "ROOT_DIR=%SCRIPT_DIR%\.."
for %%I in ("%ROOT_DIR%") do set "ROOT_DIR=%%~fI"
set "PROJECT_NAME=sstkjgf"

if /I "%~1"=="help" goto usage
if /I "%~1"=="-h" goto usage
if /I "%~1"=="--help" goto usage

set "BUILD_MODE=%~1"
set "TARGET_PLATFORM=%~2"
set "API_BASE_URL=%~3"

if "%BUILD_MODE%"=="" set "BUILD_MODE=release"

REM Backward compatible usage: build-app.bat ohos-arm64 https://web.sstkjgf.com
if /I "%BUILD_MODE:~0,5%"=="ohos-" (
    set "TARGET_PLATFORM=%BUILD_MODE%"
    set "API_BASE_URL=%~2"
    set "BUILD_MODE=release"
)

if /I "%BUILD_MODE%"=="debug" set "BUILD_MODE=debugger"
if /I not "%BUILD_MODE%"=="release" if /I not "%BUILD_MODE%"=="debugger" goto invalid_mode

if "%TARGET_PLATFORM%"=="" (
    if /I "%BUILD_MODE%"=="debugger" (
        set "TARGET_PLATFORM=ohos-x64"
    ) else (
        set "TARGET_PLATFORM=ohos-arm64"
    )
)

if /I not "%TARGET_PLATFORM%"=="ohos-arm64" if /I not "%TARGET_PLATFORM%"=="ohos-arm" if /I not "%TARGET_PLATFORM%"=="ohos-x64" goto invalid_target
if "%API_BASE_URL%"=="" set "API_BASE_URL=https://web.sstkjgf.com"

if "%FLUTTER_OHOS%"=="" set "FLUTTER_OHOS=D:\tmp\flutter_ohos_3_44"

set "DEVECO=D:\Program Files\Huawei\DevEco Studio"
set "SIGN_TOOL=%DEVECO%\sdk\default\openharmony\toolchains\lib\hap-sign-tool.jar"
set "JAVA=%DEVECO%\jbr\bin\java.exe"
set "DEVECO_SDK_HOME=%DEVECO%\sdk"
set "HOS_SDK_HOME=%DEVECO%\sdk"
set "OHOS_SDK_HOME=%DEVECO%\sdk"
set "PATH=%DEVECO%\tools\node;%DEVECO%\tools\ohpm\bin;%DEVECO%\tools\hvigor\bin;%PATH%"

set "PUB_HOSTED_URL=https://pub.flutter-io.cn"
set "FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn"

set "PUBSPEC=%SCRIPT_DIR%\pubspec.yaml"
set "APP_VERSION="
for /f "tokens=2 delims= " %%V in ('findstr /B /C:"version:" "%PUBSPEC%"') do set "APP_VERSION=%%V"
if "%APP_VERSION%"=="" set "APP_VERSION=0.0.0"
set "PACKAGE_VERSION=%APP_VERSION:+=-%"

if /I "%BUILD_MODE%"=="release" (
    set "FLUTTER_BUILD_FLAG=--release"
    set "PACKAGE_MODE=release"
    call :configure_release_signing
) else (
    set "FLUTTER_BUILD_FLAG=--debug"
    set "PACKAGE_MODE=debugger"
    call :configure_debug_signing
)
if errorlevel 1 exit /b 1

set "OUT_DIR=%SCRIPT_DIR%\ohos\build\outputs\default"
set "UNSIGNED_APP=%OUT_DIR%\ohos-default-unsigned.app"
set "DIST_DIR=%ROOT_DIR%\dist\harmonyos"
set "SIGNED_APP=%DIST_DIR%\%PROJECT_NAME%-%PACKAGE_VERSION%-%PACKAGE_MODE%.app"
set "BUILD_PROFILE_BACKUP="
set "BUILD_PROFILE_WAS_PATCHED="

call :check_required_paths
if errorlevel 1 exit /b 1

if not exist "%DIST_DIR%" mkdir "%DIST_DIR%"

echo ============================================
echo hospital-v5 HarmonyOS APP build
echo ============================================
echo Mode:      %BUILD_MODE%
echo Target:    %TARGET_PLATFORM%
echo API URL:   %API_BASE_URL%
echo Version:   %APP_VERSION%
echo Output:    %SIGNED_APP%
echo.

pushd "%SCRIPT_DIR%"

call :prepare_unsigned_build_profile
if errorlevel 1 goto fail

echo [1/5] Flutter OHOS version
call "%FLUTTER_OHOS%\bin\flutter.bat" --version
if errorlevel 1 goto fail
echo.

echo [2/5] Resolve dependencies
call "%FLUTTER_OHOS%\bin\flutter.bat" pub get
if errorlevel 1 goto fail
echo.

echo [3/5] Build unsigned APP
call "%FLUTTER_OHOS%\bin\flutter.bat" build app %FLUTTER_BUILD_FLAG% --target-platform %TARGET_PLATFORM% --dart-define=API_BASE_URL=%API_BASE_URL% --no-pub --no-codesign
if errorlevel 1 goto fail
if not exist "%UNSIGNED_APP%" (
    echo [ERROR] unsigned APP not found:
    echo   %UNSIGNED_APP%
    goto fail
)
echo.

echo [4/5] Sign APP
"%JAVA%" -jar "%SIGN_TOOL%" sign-app -keyAlias "%OHOS_KEY_ALIAS%" -signAlg SHA256withECDSA -mode localSign -appCertFile "%OHOS_CERT_FILE%" -profileFile "%OHOS_PROFILE_FILE%" -inFile "%UNSIGNED_APP%" -keystoreFile "%OHOS_KEYSTORE_FILE%" -outFile "%SIGNED_APP%" -keyPwd "%OHOS_KEY_PWD%" -keystorePwd "%OHOS_KEYSTORE_PWD%" -compatibleVersion 18
if errorlevel 1 goto fail
echo.

echo [5/5] Done
echo APP: %SIGNED_APP%
echo.

call :restore_build_profile
popd
endlocal
exit /b 0

:configure_debug_signing
set "OHOS_SIGNING_DIR=%SCRIPT_DIR%\ohos\signing"
set "OHOS_KEYSTORE_FILE=%OHOS_SIGNING_DIR%\debug.p12"
set "OHOS_CERT_FILE=%OHOS_SIGNING_DIR%\debug-app-chain.cer"
set "OHOS_PROFILE_FILE=%OHOS_SIGNING_DIR%\debug-profile.p7b"
set "OHOS_KEY_ALIAS=debug-key"
set "OHOS_KEYSTORE_PWD=123456"
set "OHOS_KEY_PWD=123456"
exit /b 0

:configure_release_signing
if "%OHOS_SIGNING_DIR%"=="" set "OHOS_SIGNING_DIR=%SCRIPT_DIR%\ohos\signing"
if exist "%OHOS_SIGNING_DIR%\release-signing.local.bat" call "%OHOS_SIGNING_DIR%\release-signing.local.bat"
call :load_release_signing_from_build_profile
if "%OHOS_KEYSTORE_FILE%"=="" if exist "%OHOS_SIGNING_DIR%\com.sstkjgf.app.hm.p12" set "OHOS_KEYSTORE_FILE=%OHOS_SIGNING_DIR%\com.sstkjgf.app.hm.p12"
if "%OHOS_CERT_FILE%"=="" if exist "%OHOS_SIGNING_DIR%\com.sstkjgf.app.hm.cer" set "OHOS_CERT_FILE=%OHOS_SIGNING_DIR%\com.sstkjgf.app.hm.cer"
if "%OHOS_PROFILE_FILE%"=="" if exist "%OHOS_SIGNING_DIR%\com.sstkjgf.app.hmRelease.p7b" set "OHOS_PROFILE_FILE=%OHOS_SIGNING_DIR%\com.sstkjgf.app.hmRelease.p7b"
if "%OHOS_KEY_ALIAS%"=="" if exist "%OHOS_SIGNING_DIR%\com.sstkjgf.app.hm.p12" set "OHOS_KEY_ALIAS=com.sstkjgf.app.hm"
if "%OHOS_KEY_ALIAS%"=="" set /p "OHOS_KEY_ALIAS=Release key alias: "
if "%OHOS_KEYSTORE_PWD%"=="" set /p "OHOS_KEYSTORE_PWD=Release keystore password: "
if "%OHOS_KEY_PWD%"=="" set /p "OHOS_KEY_PWD=Release key password, blank means same as keystore: "
if "%OHOS_KEY_PWD%"=="" set "OHOS_KEY_PWD=%OHOS_KEYSTORE_PWD%"
if "%OHOS_KEY_ALIAS%"=="" (
    echo [ERROR] release key alias is required.
    exit /b 1
)
if "%OHOS_KEYSTORE_PWD%"=="" (
    echo [ERROR] release keystore password is required.
    exit /b 1
)
exit /b 0

:load_release_signing_from_build_profile
set "OHOS_BUILD_PROFILE=%SCRIPT_DIR%\ohos\build-profile.json5"
set "OHOS_RELEASE_ENV=%TEMP%\hospital-v5-ohos-app-release-signing-%RANDOM%.bat"
if not exist "%OHOS_BUILD_PROFILE%" exit /b 0
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%\tools\emit_release_signing.ps1" -BuildProfile "%OHOS_BUILD_PROFILE%" -OhosProjectDir "%SCRIPT_DIR%\ohos" > "%OHOS_RELEASE_ENV%"
if exist "%OHOS_RELEASE_ENV%" call "%OHOS_RELEASE_ENV%"
if exist "%OHOS_RELEASE_ENV%" del /f /q "%OHOS_RELEASE_ENV%" >nul 2>nul
exit /b 0

:check_required_paths
if not exist "%FLUTTER_OHOS%\bin\flutter.bat" (
    echo [ERROR] Flutter OHOS SDK not found:
    echo   %FLUTTER_OHOS%
    exit /b 1
)
if not exist "%JAVA%" (
    echo [ERROR] Java not found:
    echo   %JAVA%
    exit /b 1
)
if not exist "%SIGN_TOOL%" (
    echo [ERROR] HAP sign tool not found:
    echo   %SIGN_TOOL%
    exit /b 1
)
call :check_file "%OHOS_KEYSTORE_FILE%" "keystore"
if errorlevel 1 exit /b 1
call :check_file "%OHOS_CERT_FILE%" "app certificate"
if errorlevel 1 exit /b 1
call :check_file "%OHOS_PROFILE_FILE%" "profile"
if errorlevel 1 exit /b 1
exit /b 0

:prepare_unsigned_build_profile
set "OHOS_BUILD_PROFILE=%SCRIPT_DIR%\ohos\build-profile.json5"
if not exist "%OHOS_BUILD_PROFILE%" exit /b 0
set "BUILD_PROFILE_BACKUP=%TEMP%\hospital-v5-app-build-profile-%RANDOM%-%RANDOM%.json5"
copy /y "%OHOS_BUILD_PROFILE%" "%BUILD_PROFILE_BACKUP%" >nul
if errorlevel 1 (
    echo [ERROR] Failed to back up build profile:
    echo   %OHOS_BUILD_PROFILE%
    exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%\tools\prepare_unsigned_build_profile.ps1" -BuildProfile "%OHOS_BUILD_PROFILE%"
if errorlevel 1 (
    echo [ERROR] Failed to prepare unsigned build profile.
    call :restore_build_profile
    exit /b 1
)
set "BUILD_PROFILE_WAS_PATCHED=1"
exit /b 0

:restore_build_profile
if "%BUILD_PROFILE_WAS_PATCHED%"=="" exit /b 0
if "%BUILD_PROFILE_BACKUP%"=="" exit /b 0
copy /y "%BUILD_PROFILE_BACKUP%" "%OHOS_BUILD_PROFILE%" >nul
if errorlevel 1 (
    echo [ERROR] Failed to restore build profile from:
    echo   %BUILD_PROFILE_BACKUP%
    exit /b 1
)
del /f /q "%BUILD_PROFILE_BACKUP%" >nul 2>nul
set "BUILD_PROFILE_WAS_PATCHED="
exit /b 0

:check_file
if not exist "%~1" (
    echo [ERROR] Missing %~2:
    echo   %~1
    exit /b 1
)
exit /b 0

:invalid_mode
echo [ERROR] Invalid mode: %BUILD_MODE%
goto usage_error

:invalid_target
echo [ERROR] Invalid target platform: %TARGET_PLATFORM%
goto usage_error

:usage
echo Usage:
echo   build-app.bat [release^|debugger] [ohos-arm64^|ohos-x64^|ohos-arm] [api_url]
echo.
echo Examples:
echo   build-app.bat release ohos-arm64 https://web.sstkjgf.com
echo   build-app.bat debugger ohos-x64 https://web.sstkjgf.com
echo.
echo Output:
echo   dist\harmonyos\sstkjgf-[version]-[release^|debugger].app
exit /b 0

:usage_error
echo.
call :usage
exit /b 1

:fail
echo.
echo [FAILED] APP build failed.
call :restore_build_profile
popd
endlocal
exit /b 1
