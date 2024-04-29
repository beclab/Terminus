#!/usr/bin/env bash




set -o pipefail

VERSION=$1

export VERSION

if [ "x${VERSION}" = "x" ]; then
  echo "Usage: bash upgrade.sh <version>"
  echo ""
  exit 1
fi

DOWNLOAD_URL="https://github.com/beclab/terminus/releases/download/${VERSION}/install-wizard-v${VERSION}.tar.gz"

echo ""
echo " Downloading Install-Wizard ${VERSION} from ${DOWNLOAD_URL} ... " 
echo ""

filename="/tmp/install-wizard-v${VERSION}.tar.gz"
curl -Lo ${filename} ${DOWNLOAD_URL}
if [ $? -ne 0 ] || [ ! -f ${filename} ]; then
  echo ""
  echo "Failed to download Install-Wizard ${VERSION} !"
  echo ""
  echo "Please verify the version you are trying to download."
  echo ""
  exit 1
fi

if command -v tar &>/dev/null; then
    tar -xzvf "${filename}"
else
    echo "Install-Wizard ${VERSION} Download Complete!"
    echo ""
    echo "Try to unpack the ${filename} failed."
    echo "tar: command not found, please unpack the ${filename} manually."
    exit 1
fi

echo ""
echo "Install-Wizard ${VERSION} Download Complete!"
echo ""

exit