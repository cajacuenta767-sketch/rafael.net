#!/bin/bash
# Hook SessionStart para Claude Code en la web.
#
# Instala el SDK de Flutter que exige pubspec.lock (Dart >= 3.13, Flutter
# >= 3.44) y descarga las dependencias del proyecto para que `flutter analyze`
# y `flutter test` funcionen desde el primer turno de la sesión.
#
# Es idempotente: si el SDK ya está en FLUTTER_HOME con la versión esperada
# solo refresca dependencias. No hace nada fuera de Claude Code en la web.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

FLUTTER_VERSION="3.47.3"
FLUTTER_HOME="${FLUTTER_HOME:-/opt/flutter}"
FLUTTER_ARCHIVE="flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/${FLUTTER_ARCHIVE}"
FLUTTER_SHA256="988665565cad9091db1baa54bf6d3868bb40e29719592f3c3a164deefd4208e1"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"

log() { echo "[session-start] $*"; }

installed_version() {
  local manifest="$FLUTTER_HOME/bin/cache/flutter.version.json"
  if [ -x "$FLUTTER_HOME/bin/flutter" ] && [ -f "$manifest" ]; then
    sed -n 's/.*"flutterVersion": *"\([^"]*\)".*/\1/p' "$manifest" | head -n 1
  fi
}

install_flutter() {
  local tmp
  tmp="$(mktemp -d)"
  log "Descargando Flutter ${FLUTTER_VERSION} estable..."
  curl -sSfL --retry 4 --retry-delay 2 -o "$tmp/$FLUTTER_ARCHIVE" "$FLUTTER_URL"
  echo "${FLUTTER_SHA256}  $tmp/$FLUTTER_ARCHIVE" | sha256sum -c - >/dev/null
  log "Extrayendo en ${FLUTTER_HOME}..."
  rm -rf "$FLUTTER_HOME"
  mkdir -p "$(dirname "$FLUTTER_HOME")"
  tar -xJf "$tmp/$FLUTTER_ARCHIVE" -C "$(dirname "$FLUTTER_HOME")"
  if [ "$(basename "$FLUTTER_HOME")" != "flutter" ]; then
    mv "$(dirname "$FLUTTER_HOME")/flutter" "$FLUTTER_HOME"
  fi
  rm -rf "$tmp"
}

if [ "$(installed_version)" != "$FLUTTER_VERSION" ]; then
  install_flutter
else
  log "Flutter ${FLUTTER_VERSION} ya está instalado en ${FLUTTER_HOME}."
fi

# El SDK se ejecuta como root en el contenedor; git lo exige explícitamente.
if ! git config --global --get-all safe.directory 2>/dev/null | grep -qx "$FLUTTER_HOME"; then
  git config --global --add safe.directory "$FLUTTER_HOME" >/dev/null 2>&1 || true
fi

export PATH="$FLUTTER_HOME/bin:$PATH"
export FLUTTER_SUPPRESS_ANALYTICS=true

# Variables que el resto de la sesión necesita.
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  {
    echo "export FLUTTER_HOME=\"$FLUTTER_HOME\""
    echo "export PATH=\"$FLUTTER_HOME/bin:\$PATH\""
    echo "export FLUTTER_SUPPRESS_ANALYTICS=true"
  } >> "$CLAUDE_ENV_FILE"
fi

flutter config --no-analytics >/dev/null 2>&1 || true
flutter --version

cd "$PROJECT_DIR"
log "Descargando dependencias del proyecto..."
flutter pub get

# Artefactos del motor que usan `flutter test` (flutter_tester) para que la
# primera prueba de la sesión no tenga que descargarlos.
flutter precache --universal --no-android --no-ios --no-web --no-linux \
  --no-windows --no-macos --no-fuchsia

log "Entorno listo: flutter analyze y flutter test disponibles."
