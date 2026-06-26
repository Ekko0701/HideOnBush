#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:-0.1.0}"
OWNER_REPO="${OWNER_REPO:-Ekko0701/HideOnBush}"
APP_NAME="HideOnBush"
SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Application: DONG JOO KIM (34JS69S5XZ)}"
NOTARY_PROFILE="${NOTARY_PROFILE:-HideOnBush}"
RELEASE_DIR="${ROOT_DIR}/release"
SUBMIT_ZIP="${RELEASE_DIR}/${APP_NAME}-notary-submit.zip"
FINAL_ZIP="${RELEASE_DIR}/${APP_NAME}-v${VERSION}-macos-arm64.zip"
CASK_OUT_DIR="${RELEASE_DIR}/homebrew/Casks"
CASK_OUT="${CASK_OUT_DIR}/hideonbush.rb"

if ! security find-identity -v -p codesigning | grep -Fq "${SIGN_IDENTITY}"; then
  echo "Missing signing identity: ${SIGN_IDENTITY}" >&2
  exit 1
fi

if ! xcrun notarytool history --keychain-profile "${NOTARY_PROFILE}" >/dev/null 2>&1; then
  cat >&2 <<EOF
Missing notarytool keychain profile: ${NOTARY_PROFILE}

Create it once with:
  xcrun notarytool store-credentials ${NOTARY_PROFILE} \\
    --apple-id "YOUR_APPLE_ID" \\
    --team-id "34JS69S5XZ" \\
    --password "APP_SPECIFIC_PASSWORD"
EOF
  exit 1
fi

rm -rf "${RELEASE_DIR}"
mkdir -p "${RELEASE_DIR}" "${CASK_OUT_DIR}"

SIGN_IDENTITY="${SIGN_IDENTITY}" "${ROOT_DIR}/scripts/build.sh"

COPYFILE_DISABLE=1 /usr/bin/ditto -c -k --norsrc --keepParent \
  "${ROOT_DIR}/dist/${APP_NAME}.app" \
  "${SUBMIT_ZIP}"

xcrun notarytool submit "${SUBMIT_ZIP}" \
  --keychain-profile "${NOTARY_PROFILE}" \
  --wait

xcrun stapler staple "${ROOT_DIR}/dist/${APP_NAME}.app"
xcrun stapler validate "${ROOT_DIR}/dist/${APP_NAME}.app"
spctl -a -vvv -t exec "${ROOT_DIR}/dist/${APP_NAME}.app"

COPYFILE_DISABLE=1 /usr/bin/ditto -c -k --norsrc --keepParent \
  "${ROOT_DIR}/dist/${APP_NAME}.app" \
  "${FINAL_ZIP}"

SHA256="$(/usr/bin/shasum -a 256 "${FINAL_ZIP}" | /usr/bin/awk '{print $1}')"

/usr/bin/sed \
  -e "s/__VERSION__/${VERSION}/g" \
  -e "s#__OWNER_REPO__#${OWNER_REPO}#g" \
  -e "s/__SHA256__/${SHA256}/g" \
  "${ROOT_DIR}/homebrew/Casks/hideonbush.rb.template" > "${CASK_OUT}"

cat <<EOF
Notarized release assets prepared.

ZIP:
  ${FINAL_ZIP}

SHA256:
  ${SHA256}

Cask:
  ${CASK_OUT}
EOF
