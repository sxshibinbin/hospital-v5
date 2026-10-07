#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_NAME="sstkjgf"

EXPORT_METHOD="${1:-app-store}"
API_BASE_URL="${2:-https://web.sstkjgf.com}"
FLUTTER_BIN="${FLUTTER_BIN:-flutter}"

case "$EXPORT_METHOD" in
  app-store|ad-hoc|development|enterprise)
    ;;
  -h|--help|help)
    cat <<'USAGE'
Usage:
  build-ios.sh [app-store|ad-hoc|development|enterprise] [api_url]

Examples:
  build-ios.sh app-store https://web.sstkjgf.com
  build-ios.sh ad-hoc https://web.sstkjgf.com
  build-ios.sh development https://web.sstkjgf.com

Output:
  ../dist/ios/sstkjgf-[version]-[export-method].ipa
USAGE
    exit 0
    ;;
  *)
    echo "[ERROR] Invalid export method: $EXPORT_METHOD" >&2
    echo "Allowed: app-store, ad-hoc, development, enterprise" >&2
    exit 1
    ;;
esac

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "[ERROR] iOS IPA builds require macOS with Xcode." >&2
  echo "Run this script on a Mac: bash build-ios.sh $EXPORT_METHOD $API_BASE_URL" >&2
  exit 1
fi

for cmd in "$FLUTTER_BIN" xcodebuild pod; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "[ERROR] Required command not found: $cmd" >&2
    exit 1
  fi
done

PUBSPEC="$SCRIPT_DIR/pubspec.yaml"
APP_VERSION="$(awk '/^version:/ { print $2; exit }' "$PUBSPEC")"
if [[ -z "$APP_VERSION" ]]; then
  APP_VERSION="0.0.0"
fi
PACKAGE_VERSION="${APP_VERSION/+/-}"
DIST_DIR="$ROOT_DIR/dist/ios"
IPA_DIR="$SCRIPT_DIR/build/ios/ipa"
SIGNED_IPA="$DIST_DIR/$PROJECT_NAME-$PACKAGE_VERSION-$EXPORT_METHOD.ipa"

export PUB_HOSTED_URL="${PUB_HOSTED_URL:-https://pub.flutter-io.cn}"
export FLUTTER_STORAGE_BASE_URL="${FLUTTER_STORAGE_BASE_URL:-https://storage.flutter-io.cn}"

if ! grep -Eq 'DEVELOPMENT_TEAM = [A-Za-z0-9]+' "$SCRIPT_DIR/ios/Runner.xcodeproj/project.pbxproj"; then
  echo "[WARN] DEVELOPMENT_TEAM is not set in ios/Runner.xcodeproj." >&2
  echo "       Configure Signing & Capabilities in Xcode before a signed archive build." >&2
fi

mkdir -p "$DIST_DIR"

echo "============================================"
echo "hospital-v5 iOS IPA build"
echo "============================================"
echo "Export:  $EXPORT_METHOD"
echo "API URL: $API_BASE_URL"
echo "Version: $APP_VERSION"
echo "Output:  $SIGNED_IPA"
echo

cd "$SCRIPT_DIR"

echo "[1/4] Flutter version"
"$FLUTTER_BIN" --version
echo

echo "[2/4] Resolve dependencies"
"$FLUTTER_BIN" pub get
echo

echo "[3/4] Build IPA"
"$FLUTTER_BIN" build ipa \
  --release \
  --no-pub \
  --export-method "$EXPORT_METHOD" \
  --dart-define "API_BASE_URL=$API_BASE_URL"
echo

echo "[4/4] Collect artifact"
IPA_FILE="$(find "$IPA_DIR" -maxdepth 1 -type f -name '*.ipa' -print | while IFS= read -r file; do printf '%s\t%s\n' "$(stat -f '%m' "$file")" "$file"; done | sort -nr | awk 'NR == 1 { sub(/^[^\t]*\t/, ""); print }')"
if [[ -z "$IPA_FILE" || ! -f "$IPA_FILE" ]]; then
  echo "[ERROR] IPA not found under $IPA_DIR" >&2
  exit 1
fi

cp "$IPA_FILE" "$SIGNED_IPA"
echo "IPA: $SIGNED_IPA"
