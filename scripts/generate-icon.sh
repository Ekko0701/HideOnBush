#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

BIN="${TMP_DIR}/icongen"
ICONSET_DIR="${TMP_DIR}/AppIcon.iconset"
RESOURCES_DIR="${ROOT_DIR}/Resources"

mkdir -p "${ICONSET_DIR}" "${RESOURCES_DIR}"

xcrun swiftc \
  -O \
  -parse-as-library \
  -target arm64-apple-macos13.0 \
  -framework AppKit \
  "${ROOT_DIR}/Sources/HideOnBush/BushIcon.swift" \
  "${ROOT_DIR}/scripts/IconGen.swift" \
  -o "${BIN}"

"${BIN}" "${ICONSET_DIR}"

iconutil -c icns "${ICONSET_DIR}" -o "${RESOURCES_DIR}/AppIcon.icns"

echo "Wrote ${RESOURCES_DIR}/AppIcon.icns"
