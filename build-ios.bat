@echo off
setlocal
chcp 65001 >nul

echo [ERROR] iOS IPA builds require macOS with Xcode.
echo Copy this repository to a Mac and run:
echo   bash build-ios.sh [app-store^|ad-hoc^|development^|enterprise] [api_url]
echo.
echo Example:
echo   bash build-ios.sh ad-hoc https://web.sstkjgf.com

endlocal
exit /b 1
