#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

APP_NAME="ConselhoJuridicoIA"
DISPLAY_NAME="Conselho Jurídico IA"
PROJECT="$APP_NAME.xcodeproj"
SCHEME="$APP_NAME"
BUILD_DIR="$ROOT/build-release"
DIST_DIR="$ROOT/dist-release"
APP_PATH="$DIST_DIR/$APP_NAME.app"
DMG_PATH="$DIST_DIR/Conselho-Juridico-IA-macOS.dmg"
ENTITLEMENTS="$ROOT/$APP_NAME/$APP_NAME.entitlements"

SIGNING_IDENTITY="${DEVELOPER_ID_APPLICATION:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"

if [[ -z "$SIGNING_IDENTITY" ]]; then
  echo "ERRO: defina DEVELOPER_ID_APPLICATION com a identidade do certificado Developer ID Application."
  echo 'Exemplo: export DEVELOPER_ID_APPLICATION="Developer ID Application: Sua Empresa (TEAMID)"'
  exit 1
fi

if [[ -z "$NOTARY_PROFILE" ]]; then
  echo "ERRO: defina NOTARY_PROFILE com um perfil já salvo no notarytool."
  echo 'Exemplo: export NOTARY_PROFILE="conselho-juridico"'
  echo 'Crie-o antes com: xcrun notarytool store-credentials conselho-juridico'
  exit 1
fi

rm -rf "$BUILD_DIR" "$DIST_DIR"
mkdir -p "$DIST_DIR"

echo "1/5 - Compilando..."
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  CODE_SIGNING_ALLOWED=NO \
  build

cp -R "$BUILD_DIR/Build/Products/Release/$APP_NAME.app" "$APP_PATH"

echo "2/5 - Assinando com Developer ID..."
codesign \
  --force \
  --deep \
  --options runtime \
  --timestamp \
  --sign "$SIGNING_IDENTITY" \
  --entitlements "$ENTITLEMENTS" \
  "$APP_PATH"

codesign --verify --deep --strict --verbose=2 "$APP_PATH"

echo "3/5 - Criando DMG..."
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

codesign --force --timestamp --sign "$SIGNING_IDENTITY" "$DMG_PATH"

echo "4/5 - Enviando para notarização da Apple..."
xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait

echo "5/5 - Anexando ticket de notarização..."
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"

echo ""
echo "Release pronta para distribuição:"
echo "$DMG_PATH"
open "$DIST_DIR"
