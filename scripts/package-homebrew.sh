#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:-0.1.0}"
OWNER_REPO="${OWNER_REPO:-YOUR_GITHUB_USER/HideOnBush}"
RELEASE_DIR="${ROOT_DIR}/release"
ZIP_NAME="HideOnBush-v${VERSION}-macos-arm64.zip"
ZIP_PATH="${RELEASE_DIR}/${ZIP_NAME}"
CASK_OUT_DIR="${RELEASE_DIR}/homebrew/Casks"
CASK_OUT="${CASK_OUT_DIR}/hideonbush.rb"

"${ROOT_DIR}/scripts/build.sh"

rm -rf "${RELEASE_DIR}"
mkdir -p "${RELEASE_DIR}" "${CASK_OUT_DIR}"

COPYFILE_DISABLE=1 /usr/bin/ditto -c -k --norsrc --keepParent \
  "${ROOT_DIR}/dist/HideOnBush.app" \
  "${ZIP_PATH}"

SHA256="$(/usr/bin/shasum -a 256 "${ZIP_PATH}" | /usr/bin/awk '{print $1}')"

/usr/bin/sed \
  -e "s/__VERSION__/${VERSION}/g" \
  -e "s#__OWNER_REPO__#${OWNER_REPO}#g" \
  -e "s/__SHA256__/${SHA256}/g" \
  "${ROOT_DIR}/homebrew/Casks/hideonbush.rb.template" > "${CASK_OUT}"

cat <<EOF
Homebrew release assets prepared.

ZIP:
  ${ZIP_PATH}

SHA256:
  ${SHA256}

Cask:
  ${CASK_OUT}

Expected GitHub Release URL:
  https://github.com/${OWNER_REPO}/releases/download/v${VERSION}/${ZIP_NAME}

Next:
  1. Upload ${ZIP_NAME} to GitHub Release v${VERSION}.
  2. Copy ${CASK_OUT} into your Homebrew tap repo at Casks/hideonbush.rb.
EOF
