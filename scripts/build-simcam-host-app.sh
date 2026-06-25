#!/usr/bin/env bash
# Empaqueta SimCamHost como .app DISTRIBUIBLE: binario + dylib de inyección embebida + firma.
# La dylib (SimCamInject.dylib, slice iphonesimulator) se compila aquí y se incrusta en
# Contents/Resources, de modo que la .app NO necesite el repo fuente ni xcodegen en la máquina
# destino. La usa DylibBuilder.bundledDylib() en tiempo de ejecución.
set -euo pipefail
HOST_DIR="$(cd "$(dirname "$0")/../SimCamHost" && pwd)"
INJECT_DIR="$(cd "$(dirname "$0")/../SimCamInject" && pwd)"
OUT="${SIMCAM_APP_OUT:-$HOME/Applications/SimCam Host.app}"
IDENTITY="${SIMCAM_SIGN_IDENTITY:--}"   # '-' = ad-hoc; usa una identidad estable para TCC persistente

echo "==> swift build -c release (host)"
( cd "$HOST_DIR" && swift build -c release --product SimCamHost )
BIN="$HOST_DIR/.build/release/SimCamHost"
test -f "$BIN" || { echo "No se encontró el binario release"; exit 1; }

echo "==> Compilando la dylib de inyección (slice iphonesimulator)"
( cd "$INJECT_DIR" && xcodegen >/dev/null )
xcrun xcodebuild -project "$INJECT_DIR/SimCamInject.xcodeproj" -scheme SimCamInject \
  -sdk iphonesimulator -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$INJECT_DIR/.build-xcode" build >/dev/null
DYLIB="$(/usr/bin/find "$INJECT_DIR/.build-xcode/Build/Products/Debug-iphonesimulator" -maxdepth 1 -name '*.dylib' -type f | head -1)"
test -n "$DYLIB" && test -f "$DYLIB" || { echo "No se encontró la dylib"; exit 1; }
echo "    dylib: $DYLIB"

echo "==> Construyendo bundle $OUT"
rm -rf "$OUT"
mkdir -p "$OUT/Contents/MacOS" "$OUT/Contents/Resources"
cp "$BIN" "$OUT/Contents/MacOS/SimCamHost"
cp "$HOST_DIR/Resources/Info.plist" "$OUT/Contents/Info.plist"
cp "$DYLIB" "$OUT/Contents/Resources/SimCamInject.dylib"   # dylib embebida (la usa DylibBuilder.bundledDylib)

echo "==> Firmando ($IDENTITY)"
codesign --force --deep --sign "$IDENTITY" "$OUT"
echo "==> Listo: $OUT (dylib embebida)"
echo "   Ábrela una vez y concede 'Grabación de pantalla' en Ajustes del Sistema → Privacidad y Seguridad."
