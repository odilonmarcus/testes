#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

APP_NAME="ConselhoJuridicoIA"
DISPLAY_NAME="Conselho Jurídico IA"
PROJECT="$APP_NAME.xcodeproj"
SCHEME="$APP_NAME"
BUILD_DIR="$ROOT/build"
DIST_DIR="$ROOT/dist"
APP_PATH="$DIST_DIR/$APP_NAME.app"
DMG_PATH="$DIST_DIR/Conselho-Juridico-IA-macOS.dmg"
ENTITLEMENTS="$ROOT/$APP_NAME/$APP_NAME.entitlements"

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "ERRO: Xcode não foi encontrado. Instale o Xcode pela App Store e abra-o pelo menos uma vez."
  exit 1
fi

if ! command -v hdiutil >/dev/null 2>&1; then
  echo "ERRO: hdiutil não foi encontrado neste Mac."
  exit 1
fi

mkdir -p "$DIST_DIR"
rm -rf "$BUILD_DIR" "$APP_PATH" "$DMG_PATH" "$DIST_DIR/dmg-root"

echo "1/4 - Compilando o aplicativo..."
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  CODE_SIGNING_ALLOWED=NO \
  build

cp -R "$BUILD_DIR/Build/Products/Release/$APP_NAME.app" "$APP_PATH"

echo "2/4 - Assinando localmente..."
codesign \
  --force \
  --deep \
  --sign - \
  --entitlements "$ENTITLEMENTS" \
  "$APP_PATH"

codesign --verify --deep --strict "$APP_PATH"

echo "3/4 - Criando instalador DMG..."
mkdir -p "$DIST_DIR/dmg-root"
cp -R "$APP_PATH" "$DIST_DIR/dmg-root/"
ln -s /Applications "$DIST_DIR/dmg-root/Applications"

hdiutil create \
  -volname "$DISPLAY_NAME" \
  -srcfolder "$DIST_DIR/dmg-root" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

rm -rf "$DIST_DIR/dmg-root"

echo "4/4 - Concluído."
echo ""
echo "Aplicativo: $APP_PATH"
echo "Instalador:  $DMG_PATH"
echo ""
echo "Esta versão é assinada localmente para testes. Para distribuição sem alerta do Gatekeeper, use release_notarized.command com Apple Developer ID."

if [[ -z "${CI:-}" ]]; then
  open "$DIST_DIR"
fi
