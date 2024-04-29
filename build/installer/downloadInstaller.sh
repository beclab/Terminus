#!/usr/bin/env bash



set -o pipefail

if [ "x${VERSION}" = "x" ]; then
  echo "Unable to get latest Install-Wizard version. Set VERSION env var and re-run. For example: export VERSION=1.0.0"
  echo ""
  exit
fi

if [ "x${TOKEN}" = "x" ]; then
  echo "Unable to get your github token. Set TOKEN env var and re-run. ( In dev version, repo is private)"
  echo ""
  exit
fi

gh_curl(){
    curl -H "Authorization: Bearer $TOKEN" $@
}


TAG_URL="https://api.github.com/repos/beclab/terminus/releases/tags/${VERSION}"
ASSET_URL=$(gh_curl -fsS ${TAG_URL}  | grep '"url"'| grep assets | awk -F':|,' '{print $3}'| tr '"' ' ')

if [ "x${ASSET_URL}" = "x" ]; then
    echo ""
    echo "Fail to get Install-Wizard release asset!"
    echo ""
fi

DOWNLOAD_URL="https:${ASSET_URL}"

echo ""
echo "Downloading Install-Wizard ${VERSION} from ${DOWNLOAD_URL} ..."
echo ""

filename="install-wizard-v${VERSION}.tar.gz"
curl -H "Authorization: Bearer ${TOKEN}" -H "Accept: application/octet-stream" -Lo ${filename} ${DOWNLOAD_URL}
if [ $? -ne 0 ] || [ ! -f ${filename} ]; then
  echo ""
  echo "Failed to download Install-Wizard ${VERSION} !"
  echo ""
  echo "Please verify the version you are trying to download."
  echo ""
  exit
fi

ret='0'
command -v tar >/dev/null 2>&1 || { ret='1'; }
if [ "$ret" -eq 0 ]; then
    mkdir -p install-wizard && cd install-wizard && tar -xzf "../${filename}"
else
    echo "Install-Wizard ${VERSION} Download Complete!"
    echo ""
    echo "Try to unpack the ${filename} failed."
    echo "tar: command not found, please unpack the ${filename} manually."
    exit
fi

echo ""
echo "Install-Wizard ${VERSION} Download Complete!"
echo ""


bash ./install_cmd.sh
