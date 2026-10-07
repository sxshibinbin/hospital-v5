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
set "SIGNING_MODE="
set "BUILD_PROFILE_BACKUP="
set "BUILD_PROFILE_WAS_PATCHED="

REM Keep local HAP packages installable on registered test devices by default.
REM Production release packaging must be requested explicitly with `release`.
if "%BUILD_MODE%"=="" set "BUILD_MODE=debugger"

if /I "%BUILD_MODE%"=="device" (
    set "BUILD_MODE=debugger"
    set "SIGNING_MODE=debugger"
    set "TARGET_PLATFORM=ohos-arm64"
    set "API_BASE_URL=%~2"
)
if /I "%BUILD_MODE%"=="device-release" (
    set "BUILD_MODE=release"
    set "SIGNING_MODE=debugger"
    set "TARGET_PLATFORM=ohos-arm64"
    set "API_BASE_URL=%~2"
)
if /I "%BUILD_MODE%"=="simulator" (
    set "BUILD_MODE=debugger"
    set "SIGNING_MODE=debugger"
    set "TARGET_PLATFORM=ohos-x64"
    set "API_BASE_URL=%~2"
)

REM Backward compatible usage: build-hap.bat ohos-x64 https://web.sstkjgf.com
if /I "%BUILD_MODE:~0,5%"=="ohos-" (
    set "TARGET_PLATFORM=%BUILD_MODE%"
    set "API_BASE_URL=%~2"
    set "BUILD_MODE=release"
)

if /I "%BUILD_MODE%"=="debug" set "BUILD_MODE=debugger"
if /I not "%BUILD_MODE%"=="release" if /I not "%BUILD_MODE%"=="debugger" goto invalid_mode
if "%SIGNING_MODE%"=="" set "SIGNING_MODE=%BUILD_MODE%"
if /I "%SIGNING_MODE%"=="debug" set "SIGNING_MODE=debugger"
if /I not "%SIGNING_MODE%"=="release" if /I not "%SIGNING_MODE%"=="debugger" goto invalid_signing_mode

if "%TARGET_PLATFORM%"=="" (
    if /I "%BUILD_MODE%"=="debugger" (
        set "TARGET_PLATFORM=ohos-arm64"
        echo [INFO] Debugger mode defaults to ohos-arm64 for real-phone testing.
        echo        Use "build-hap.bat simulator" or pass ohos-x64 for emulator builds.
    ) else (
        set "TARGET_PLATFORM=ohos-arm64"
    )
)

if /I not "%TARGET_PLATFORM%"=="ohos-arm64" if /I not "%TARGET_PLATFORM%"=="ohos-arm" if /I not "%TARGET_PLATFORM%"=="ohos-x64" goto invalid_target
set "TARGET_ARCH_LABEL=%TARGET_PLATFORM%"
if /I "%TARGET_PLATFORM%"=="ohos-arm64" set "TARGET_ARCH_LABEL=arm64"
if /I "%TARGET_PLATFORM%"=="ohos-arm" set "TARGET_ARCH_LABEL=arm"
if /I "%TARGET_PLATFORM%"=="ohos-x64" set "TARGET_ARCH_LABEL=x64"
set "TARGET_ABI_DIR=%TARGET_ARCH_LABEL%"
if /I "%TARGET_PLATFORM%"=="ohos-arm64" set "TARGET_ABI_DIR=arm64-v8a"
if /I "%TARGET_PLATFORM%"=="ohos-arm" set "TARGET_ABI_DIR=armeabi-v7a"
if /I "%TARGET_PLATFORM%"=="ohos-x64" set "TARGET_ABI_DIR=x86_64"
if "%API_BASE_URL%"=="" set "API_BASE_URL=https://web.sstkjgf.com"

if "%FLUTTER_OHOS%"=="" set "FLUTTER_OHOS=D:\tmp\flutter_ohos_3_44"

set "DEVECO=D:\Program Files\Huawei\DevEco Studio"
set "SIGN_TOOL=%DEVECO%\sdk\default\openharmony\toolchains\lib\hap-sign-tool.jar"
set "JAVA=%DEVECO%\jbr\bin\java.exe"
set "DEVECO_SDK_HOME=%DEVECO%\sdk"
set "HOS_SDK_HOME=%DEVECO%\sdk"
set "OHOS_SDK_HOME=%DEVECO%\sdk"
set "PATH=%DEVECO%\tools\node;%DEVECO%\tools\ohpm\bin;%DEVECO%\tools\hvigor\bin;%PATH%"

set "PUBSPEC=%SCRIPT_DIR%\pubspec.yaml"
set "PUBSPEC_LOCK=%SCRIPT_DIR%\pubspec.lock"
set "ALIYUN_HARMONY_AUTH_FILE=%SCRIPT_DIR%\ohos\aliyun-number-auth.local.properties"
set "EXTRA_DART_DEFINES="
if "%PUB_HOSTED_URL%"=="" (
    if exist "%PUBSPEC_LOCK%" (
        findstr /C:"url: \"https://pub.flutter-io.cn\"" "%PUBSPEC_LOCK%" >nul 2>nul
        if not errorlevel 1 set "PUB_HOSTED_URL=https://pub.flutter-io.cn"
    )
)
if "%PUB_HOSTED_URL%"=="" set "PUB_HOSTED_URL=https://pub.dev"
if "%FLUTTER_STORAGE_BASE_URL%"=="" set "FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn"
set "ALIYUN_NUMBER_AUTH_HARMONY_SK_FROM_ENV=%ALIYUN_NUMBER_AUTH_HARMONY_SK%"
set "ALIYUN_NUMBER_AUTH_HARMONY_SK="
if exist "%ALIYUN_HARMONY_AUTH_FILE%" (
    for /f "usebackq tokens=1,* delims==" %%K in (`findstr /B /C:"ALIYUN_NUMBER_AUTH_HARMONY_SK=" "%ALIYUN_HARMONY_AUTH_FILE%"`) do set "ALIYUN_NUMBER_AUTH_HARMONY_SK=%%L"
)
if not defined ALIYUN_NUMBER_AUTH_HARMONY_SK if exist "%ALIYUN_HARMONY_AUTH_FILE%" for /f "usebackq tokens=1,* delims==" %%K in (`findstr /B /C:"ALIYUN_NUMBER_AUTH_ANDROID_SK=" "%ALIYUN_HARMONY_AUTH_FILE%"`) do set "ALIYUN_NUMBER_AUTH_HARMONY_SK=%%L"
if not defined ALIYUN_NUMBER_AUTH_HARMONY_SK if defined ALIYUN_NUMBER_AUTH_OHOS_SK set "ALIYUN_NUMBER_AUTH_HARMONY_SK=%ALIYUN_NUMBER_AUTH_OHOS_SK%"
if not defined ALIYUN_NUMBER_AUTH_HARMONY_SK if defined ALIYUN_NUMBER_AUTH_HARMONY_SK_FROM_ENV set "ALIYUN_NUMBER_AUTH_HARMONY_SK=%ALIYUN_NUMBER_AUTH_HARMONY_SK_FROM_ENV%"
if not "%ALIYUN_NUMBER_AUTH_HARMONY_SK%"=="" set "EXTRA_DART_DEFINES=%EXTRA_DART_DEFINES% --dart-define=ALIYUN_NUMBER_AUTH_HARMONY_SK=%ALIYUN_NUMBER_AUTH_HARMONY_SK%"
if /I "%BUILD_MODE%"=="release" set "HAP_FULL_REBUILD=1"

set "APP_VERSION="
for /f "tokens=2 delims= " %%V in ('findstr /B /C:"version:" "%PUBSPEC%"') do set "APP_VERSION=%%V"
if "%APP_VERSION%"=="" set "APP_VERSION=0.0.0"
set "PACKAGE_VERSION=%APP_VERSION:+=-%"

if /I "%BUILD_MODE%"=="release" (
    set "FLUTTER_BUILD_FLAG=--release"
)
if /I "%BUILD_MODE%"=="debugger" (
    set "FLUTTER_BUILD_FLAG=--debug"
)

if /I "%SIGNING_MODE%"=="release" (
    set "SIGNING_LABEL=release"
    call :configure_release_signing
) else (
    set "SIGNING_LABEL=debug"
    call :configure_debug_signing
)
if errorlevel 1 exit /b 1
set "PACKAGE_MODE=%BUILD_MODE%"
if /I not "%SIGNING_MODE%"=="%BUILD_MODE%" set "PACKAGE_MODE=%BUILD_MODE%-%SIGNING_LABEL%-signed"

set "OUT_DIR=%SCRIPT_DIR%\ohos\entry\build\default\outputs\default"
set "UNSIGNED_HAP=%OUT_DIR%\entry-default-unsigned.hap"
set "DIST_DIR=%ROOT_DIR%\dist\harmonyos"
set "SIGNED_HAP=%DIST_DIR%\%PROJECT_NAME%-%PACKAGE_VERSION%-%PACKAGE_MODE%-%TARGET_ARCH_LABEL%.hap"

call :check_required_paths
if errorlevel 1 exit /b 1

if not exist "%DIST_DIR%" mkdir "%DIST_DIR%"

echo ============================================
echo hospital-v5 HarmonyOS HAP build
echo ============================================
echo Mode:      %BUILD_MODE%
echo Signing:   %SIGNING_LABEL%
echo Target:    %TARGET_PLATFORM%
echo API URL:   %API_BASE_URL%
echo Version:   %APP_VERSION%
echo Output:    %SIGNED_HAP%
echo.

pushd "%SCRIPT_DIR%"

if exist "%UNSIGNED_HAP%" del /f /q "%UNSIGNED_HAP%" >nul 2>nul
if exist "%SIGNED_HAP%" del /f /q "%SIGNED_HAP%" >nul 2>nul

echo [1/7] Flutter OHOS version
call "%FLUTTER_OHOS%\bin\flutter.bat" --version
if errorlevel 1 goto fail
echo.

if "%HAP_FULL_REBUILD%"=="1" (
    echo [2/7] Clean Flutter build cache
    call "%FLUTTER_OHOS%\bin\flutter.bat" clean
    if errorlevel 1 goto fail
    echo.

    echo [3/7] Resolve dependencies
    call "%FLUTTER_OHOS%\bin\flutter.bat" pub get
    if errorlevel 1 goto fail
    echo.
) else (
    echo [2/7] Skip Flutter clean / pub get for incremental debug build
    echo.
)

echo [4/7] Build unsigned HAP
call :prepare_unsigned_build_profile
if errorlevel 1 goto fail
call "%FLUTTER_OHOS%\bin\flutter.bat" build hap %FLUTTER_BUILD_FLAG% --target-platform %TARGET_PLATFORM% --dart-define=API_BASE_URL=%API_BASE_URL%%EXTRA_DART_DEFINES% --no-pub --no-codesign
set "FLUTTER_BUILD_EXIT=%ERRORLEVEL%"
call :restore_build_profile
if errorlevel 1 goto fail
if not "%FLUTTER_BUILD_EXIT%"=="0" goto fail
if not exist "%UNSIGNED_HAP%" (
    echo [ERROR] unsigned HAP not found:
    echo   %UNSIGNED_HAP%
    goto fail
)
echo.

echo [5/7] Sign HAP
"%JAVA%" -jar "%SIGN_TOOL%" sign-app -keyAlias "%OHOS_KEY_ALIAS%" -signAlg SHA256withECDSA -mode localSign -appCertFile "%OHOS_CERT_FILE%" -profileFile "%OHOS_PROFILE_FILE%" -inFile "%UNSIGNED_HAP%" -keystoreFile "%OHOS_KEYSTORE_FILE%" -outFile "%SIGNED_HAP%" -keyPwd "%OHOS_KEY_PWD%" -keystorePwd "%OHOS_KEYSTORE_PWD%" -compatibleVersion 18 -signCode 1
if errorlevel 1 goto fail
echo.

echo [6/7] Verify signed HAP
set "VERIFY_CERT_CHAIN=%OUT_DIR%\verify-cert-chain.cer"
set "VERIFY_PROFILE=%OUT_DIR%\verify-profile.p7b"
"%JAVA%" -jar "%SIGN_TOOL%" verify-app -inFile "%SIGNED_HAP%" -outCertChain "%VERIFY_CERT_CHAIN%" -outProfile "%VERIFY_PROFILE%"
if errorlevel 1 goto fail
if exist "%VERIFY_CERT_CHAIN%" del /f /q "%VERIFY_CERT_CHAIN%" >nul 2>nul
if exist "%VERIFY_PROFILE%" del /f /q "%VERIFY_PROFILE%" >nul 2>nul
where tar >nul 2>nul
if not errorlevel 1 (
    tar -tf "%SIGNED_HAP%" | findstr /I /C:"libs/%TARGET_ABI_DIR%/libflutter.so" >nul
    if errorlevel 1 (
        echo [ERROR] Signed HAP does not contain expected ABI library:
        echo   libs/%TARGET_ABI_DIR%/libflutter.so
        goto fail
    )
)
echo.

echo [7/7] Done
echo HAP: %SIGNED_HAP%
echo.

popd
endlocal
exit /b 0

:configure_debug_signing
if "%OHOS_DEBUG_SIGNING_DIR%"=="" if not "%OHOS_SIGNING_DIR%"=="" set "OHOS_DEBUG_SIGNING_DIR=%OHOS_SIGNING_DIR%"
if "%OHOS_DEBUG_SIGNING_DIR%"=="" set "OHOS_DEBUG_SIGNING_DIR=%SCRIPT_DIR%\ohos\signing"
set "OHOS_SIGNING_DIR=%OHOS_DEBUG_SIGNING_DIR%"
if exist "%OHOS_SIGNING_DIR%\debug-signing.local.bat" call "%OHOS_SIGNING_DIR%\debug-signing.local.bat"
set "OHOS_SIGNING_CONFIG_NAME=debug"
call :load_signing_from_build_profile
if "%OHOS_KEYSTORE_FILE%"=="" if exist "%OHOS_SIGNING_DIR%\com.sstkjgf.app.hm.p12" set "OHOS_KEYSTORE_FILE=%OHOS_SIGNING_DIR%\com.sstkjgf.app.hm.p12"
if "%OHOS_CERT_FILE%"=="" if exist "%OHOS_SIGNING_DIR%\com.sstkjgf.app.hm.debug.cer" set "OHOS_CERT_FILE=%OHOS_SIGNING_DIR%\com.sstkjgf.app.hm.debug.cer"
if "%OHOS_PROFILE_FILE%"=="" if exist "%OHOS_SIGNING_DIR%\com.sstkjgf.app.hm.debugDebug.p7b" set "OHOS_PROFILE_FILE=%OHOS_SIGNING_DIR%\com.sstkjgf.app.hm.debugDebug.p7b"
if "%OHOS_KEY_ALIAS%"=="" if exist "%OHOS_SIGNING_DIR%\com.sstkjgf.app.hm.p12" set "OHOS_KEY_ALIAS=com.sstkjgf.app.hm"
if "%OHOS_KEYSTORE_FILE%"=="" set "OHOS_KEYSTORE_FILE=%OHOS_SIGNING_DIR%\debug.p12"
if "%OHOS_CERT_FILE%"=="" set "OHOS_CERT_FILE=%OHOS_SIGNING_DIR%\debug-app-chain.cer"
if "%OHOS_PROFILE_FILE%"=="" set "OHOS_PROFILE_FILE=%OHOS_SIGNING_DIR%\debug-profile.p7b"
if "%OHOS_KEY_ALIAS%"=="" set "OHOS_KEY_ALIAS=debug-key"
if "%OHOS_KEYSTORE_PWD%"=="" set "OHOS_KEYSTORE_PWD=123456"
if "%OHOS_KEY_PWD%"=="" set "OHOS_KEY_PWD=%OHOS_KEYSTORE_PWD%"
exit /b 0

:configure_release_signing
if "%OHOS_SIGNING_DIR%"=="" set "OHOS_SIGNING_DIR=%SCRIPT_DIR%\ohos\signing"
if exist "%OHOS_SIGNING_DIR%\release-signing.local.bat" call "%OHOS_SIGNING_DIR%\release-signing.local.bat"
if exist "%OHOS_SIGNING_DIR%\release\release-signing.local.bat" call "%OHOS_SIGNING_DIR%\release\release-signing.local.bat"
call :load_release_signing_from_build_profile
if "%OHOS_KEYSTORE_FILE%"=="" if exist "%OHOS_SIGNING_DIR%\com.sstkjgf.app.hm.p12" set "OHOS_KEYSTORE_FILE=%OHOS_SIGNING_DIR%\com.sstkjgf.app.hm.p12"
if "%OHOS_CERT_FILE%"=="" if exist "%OHOS_SIGNING_DIR%\com.sstkjgf.app.hm.cer" set "OHOS_CERT_FILE=%OHOS_SIGNING_DIR%\com.sstkjgf.app.hm.cer"
if "%OHOS_PROFILE_FILE%"=="" if exist "%OHOS_SIGNING_DIR%\com.sstkjgf.app.hmRelease.p7b" set "OHOS_PROFILE_FILE=%OHOS_SIGNING_DIR%\com.sstkjgf.app.hmRelease.p7b"
if "%OHOS_KEY_ALIAS%"=="" if exist "%OHOS_SIGNING_DIR%\com.sstkjgf.app.hm.p12" set "OHOS_KEY_ALIAS=com.sstkjgf.app.hm"
if "%OHOS_KEYSTORE_FILE%"=="" set "OHOS_KEYSTORE_FILE=%OHOS_SIGNING_DIR%\release.p12"
if "%OHOS_CERT_FILE%"=="" if exist "%OHOS_SIGNING_DIR%\release-app-chain.cer" set "OHOS_CERT_FILE=%OHOS_SIGNING_DIR%\release-app-chain.cer"
if "%OHOS_CERT_FILE%"=="" if exist "%OHOS_SIGNING_DIR%\release-app.cer" set "OHOS_CERT_FILE=%OHOS_SIGNING_DIR%\release-app.cer"
if "%OHOS_CERT_FILE%"=="" set "OHOS_CERT_FILE=%OHOS_SIGNING_DIR%\release.cer"
if "%OHOS_PROFILE_FILE%"=="" set "OHOS_PROFILE_FILE=%OHOS_SIGNING_DIR%\release-profile.p7b"
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

:prepare_unsigned_build_profile
set "OHOS_BUILD_PROFILE=%SCRIPT_DIR%\ohos\build-profile.json5"
if not exist "%OHOS_BUILD_PROFILE%" exit /b 0
set "BUILD_PROFILE_BACKUP=%TEMP%\hospital-v5-build-profile-%RANDOM%-%RANDOM%.json5"
copy /y "%OHOS_BUILD_PROFILE%" "%BUILD_PROFILE_BACKUP%" >nul
if errorlevel 1 (
    echo [ERROR] Failed to back up build profile:
    echo   %OHOS_BUILD_PROFILE%
    exit /b 1
)
set "BUILD_PROFILE_WAS_PATCHED=1"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $path = $env:OHOS_BUILD_PROFILE; $buildProfile = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json; foreach ($product in @($buildProfile.app.products)) { $prop = $product.PSObject.Properties['signingConfig']; if ($null -ne $prop) { $product.PSObject.Properties.Remove('signingConfig') } }; $json = $buildProfile | ConvertTo-Json -Depth 64; $enc = New-Object System.Text.UTF8Encoding -ArgumentList $false; [System.IO.File]::WriteAllText($path, $json, $enc)"
if errorlevel 1 (
    echo [ERROR] Failed to prepare unsigned build profile:
    echo   %OHOS_BUILD_PROFILE%
    call :restore_build_profile
    exit /b 1
)
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
set "BUILD_PROFILE_BACKUP="
set "BUILD_PROFILE_WAS_PATCHED="
exit /b 0

:load_release_signing_from_build_profile
set "OHOS_SIGNING_CONFIG_NAME=release"
call :load_signing_from_build_profile
exit /b %ERRORLEVEL%

:load_signing_from_build_profile
set "OHOS_BUILD_PROFILE=%SCRIPT_DIR%\ohos\build-profile.json5"
if not exist "%OHOS_BUILD_PROFILE%" exit /b 0
set "OHOS_PROJECT_DIR=%SCRIPT_DIR%\ohos"
set "OHOS_RELEASE_ENV=%TEMP%\hospital-v5-ohos-release-signing-%RANDOM%.bat"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $q = [char]34; $signingName = $env:OHOS_SIGNING_CONFIG_NAME; $buildProfile = Get-Content -LiteralPath $env:OHOS_BUILD_PROFILE -Raw | ConvertFrom-Json; $cfg = @($buildProfile.app.signingConfigs) | Where-Object { $_.name -eq $signingName } | Select-Object -First 1; if ($null -eq $cfg) { exit 0 }; $m = $cfg.material; function ResolveMaterialPath([string]$p) { if ([string]::IsNullOrWhiteSpace($p)) { return '' }; if ([System.IO.Path]::IsPathRooted($p)) { return $p }; return [System.IO.Path]::GetFullPath((Join-Path $env:OHOS_PROJECT_DIR $p)) }; function Emit([string]$n, [string]$v) { if (-not [string]::IsNullOrWhiteSpace($v)) { Write-Output ('if not defined ' + $n + ' set ' + $q + $n + '=' + $v + $q) } }; Emit 'OHOS_KEY_ALIAS' $m.keyAlias; Emit 'OHOS_KEY_PWD' $m.keyPassword; Emit 'OHOS_KEYSTORE_PWD' $m.storePassword; Emit 'OHOS_KEYSTORE_FILE' (ResolveMaterialPath $m.storeFile); Emit 'OHOS_CERT_FILE' (ResolveMaterialPath $m.certpath); Emit 'OHOS_PROFILE_FILE' (ResolveMaterialPath $m.profile)" > "%OHOS_RELEASE_ENV%"
if errorlevel 1 (
    echo [WARN] Failed to read %OHOS_SIGNING_CONFIG_NAME% signing config from:
    echo   %OHOS_BUILD_PROFILE%
    if exist "%OHOS_RELEASE_ENV%" del /f /q "%OHOS_RELEASE_ENV%" >nul 2>nul
    exit /b 0
)
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
if /I "%SIGNING_MODE%"=="debugger" call :warn_placeholder_debug_profile
exit /b 0

:warn_placeholder_debug_profile
if /I not "%OHOS_PROFILE_FILE%"=="%OHOS_SIGNING_DIR%\debug-profile.p7b" exit /b 0
if exist "%OHOS_SIGNING_DIR%\debug-profile.json" (
    findstr /C:"FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF" "%OHOS_SIGNING_DIR%\debug-profile.json" >nul 2>nul
    if not errorlevel 1 (
        echo [WARN] The debug profile appears to contain the placeholder UDID.
        echo        Real-phone install requires an AGC debug profile bound to the phone UDID.
    )
)
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

:invalid_signing_mode
echo [ERROR] Invalid signing mode: %SIGNING_MODE%
goto usage_error

:invalid_target
echo [ERROR] Invalid target platform: %TARGET_PLATFORM%
goto usage_error

:usage
echo Usage:
echo   build-hap.bat [release^|debugger] [ohos-arm64^|ohos-x64^|ohos-arm] [api_url]
echo   build-hap.bat [device^|device-release^|simulator] [api_url]
echo.
echo Examples:
echo   build-hap.bat release ohos-arm64 https://web.sstkjgf.com
echo   build-hap.bat device https://web.sstkjgf.com
echo   build-hap.bat device-release https://web.sstkjgf.com
echo   build-hap.bat debugger ohos-x64 https://web.sstkjgf.com
echo.
echo Output:
echo   dist\harmonyos\sstkjgf-[version]-[mode]-[arm64^|x64^|arm].hap
exit /b 0

:usage_error
echo.
call :usage
exit /b 1

:fail
echo.
echo [FAILED] HAP build failed.
call :restore_build_profile
popd
endlocal
exit /b 1
