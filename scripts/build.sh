#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="HideOnBush"
DIST_DIR="${ROOT_DIR}/dist"
APP_DIR="${DIST_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"

rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}"

cp "${ROOT_DIR}/Info.plist" "${CONTENTS_DIR}/Info.plist"

if [[ -f "${ROOT_DIR}/Resources/AppIcon.icns" ]]; then
  mkdir -p "${CONTENTS_DIR}/Resources"
  cp "${ROOT_DIR}/Resources/AppIcon.icns" "${CONTENTS_DIR}/Resources/AppIcon.icns"
fi

xcrun swiftc \
  -O \
  -parse-as-library \
  -target arm64-apple-macos13.0 \
  -framework AppKit \
  "${ROOT_DIR}/Sources/HideOnBush/BushIcon.swift" \
  "${ROOT_DIR}/Sources/HideOnBush/main.swift" \
  -o "${MACOS_DIR}/${APP_NAME}"

if [[ "${SIGN_IDENTITY}" == "-" ]]; then
  codesign --force --deep --sign - "${APP_DIR}" >/dev/null
else
  codesign --force --deep --options runtime --timestamp --sign "${SIGN_IDENTITY}" "${APP_DIR}" >/dev/null
fi

echo "Built ${APP_DIR}"
