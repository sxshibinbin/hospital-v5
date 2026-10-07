#!/usr/bin/env bash
# iOS 真机 ad-hoc 包构建脚本（macOS）——把包装进 iOS 17+ 真机（如 iOS 18.6.2）用
# 原理: 打包/签名只跟苹果开发者门户 API 通信，不需要 Xcode 认识这台手机，
#       因此 Xcode 14.2 无法调试 iOS 18 手机，但完全可以给它出包。
# 前提: ①付费开发者账号 ②目标手机 UDID 已在 developer.apple.com 注册
#       ③Xcode → Settings → Accounts 登录了对应团队 Apple ID
# 用法: ./build-ios-adhoc.sh [API_BASE_URL] [额外 flutter build 参数...]
#   默认 API_BASE_URL=https://web.sstkjgf.com
# 密钥: android/aliyun-number-auth.local.properties 的 ALIYUN_NUMBER_AUTH_IOS_SK 行（与 build-ios.sh 同源）
# 签名: ios/ExportOptions-adhoc.plist（teamID=HDTYXYQC82，自动签名）
#   首次使用前需在 Xcode 里对 Runner 设一次 Team（Signing & Capabilities 选 Thirty Days Technology），
#   或改走手动签名：把门户下载的 .mobileprovision 双击导入，Runner 改 Manual 选该 profile。
# 产物: build/ios/ipa/*.ipa → 拷贝到仓库根 dist/IOS/
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
KEY_FILE="$ROOT/android/aliyun-number-auth.local.properties"
API_BASE_URL="${1:-https://web.sstkjgf.com}"
if [ "$#" -gt 0 ]; then shift; fi

export PUB_HOSTED_URL="https://pub.flutter-io.cn"
export FLUTTER_STORAGE_BASE_URL="https://storage.flutter-io.cn"
export PATH="/Users/sunaijing/flutter-3.38.10/bin:$PATH"

DEFINES=(--dart-define="API_BASE_URL=$API_BASE_URL")
if [ -f "$KEY_FILE" ]; then
  IOS_SK="$(awk -F= '/^[[:space:]]*ALIYUN_NUMBER_AUTH_IOS_SK[[:space:]]*=/{sub(/^[^=]*=/,""); gsub(/[\r\n]/,""); print; exit}' "$KEY_FILE")"
  if [ -n "$IOS_SK" ]; then
    DEFINES+=(--dart-define="ALIYUN_NUMBER_AUTH_IOS_SK=$IOS_SK")
    echo "Aliyun: local number auth config found (iOS SK loaded)"
  else
    echo "Aliyun: key file found but no ALIYUN_NUMBER_AUTH_IOS_SK line, one-click login disabled"
  fi
else
  echo "Aliyun: local number auth config not found, one-click login disabled"
fi

echo "API_BASE_URL: $API_BASE_URL"
echo "Target:      iOS device (release, ad-hoc export)"
cd "$ROOT"
flutter build ipa --release --export-options-plist="$ROOT/ios/ExportOptions-adhoc.plist" "${DEFINES[@]}" "$@"

IPA_DIR="$ROOT/build/ios/ipa"
DIST_DIR="$(dirname "$ROOT")/dist/IOS"
if compgen -G "$IPA_DIR/*.ipa" > /dev/null; then
  mkdir -p "$DIST_DIR"
  cp -f "$IPA_DIR"/*.ipa "$DIST_DIR"/
  echo "Output:      $DIST_DIR/"
else
  echo "[WARN] no ipa produced at $IPA_DIR"
fi
