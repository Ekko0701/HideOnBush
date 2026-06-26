#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="HideOnBush"
DIST_DIR="${ROOT_DIR}/dist"
APP_DIR="${DIST_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"

rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}"

cp "${ROOT_DIR}/Info.plist" "${CONTENTS_DIR}/Info.plist"

xcrun swiftc \
  -O \
  -parse-as-library \
  -target arm64-apple-macos13.0 \
  -framework AppKit \
  "${ROOT_DIR}/Sources/HideOnBush/main.swift" \
  -o "${MACOS_DIR}/${APP_NAME}"

codesign --force --deep --sign - "${APP_DIR}" >/dev/null

echo "Built ${APP_DIR}"
