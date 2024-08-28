#!/usr/bin/env bash



set -o pipefail
set -e

export VERSION="#__VERSION__"
if [ "x${VERSION}" = "x" ]; then
  echo "Unable to get latest Install-Wizard version. Set VERSION env var and re-run. For example: export VERSION=1.0.0"
  echo ""
  exit
fi

# check os type and arch and os vesion
os_type=$(uname -s)
os_arch=$(uname -m)
os_verion=$(lsb_release -d 2>&1 | awk -F'\t' '{print $2}')

case "$os_arch" in 
    arm64) ARCH=arm64; ;; 
    x86_64) ARCH=amd64; ;; 
    armv7l) ARCH=arm; ;; 
    aarch64) ARCH=arm64; ;; 
    ppc64le) ARCH=ppc64le; ;; 
    s390x) ARCH=s390x; ;; 
    *) echo "unsupported arch, exit ..."; 
    exit -1; ;; 
esac 


if [[ x"$os_type" != x"Darwin" ]]; then
  if command -v sudo > /dev/null; then
    SUDO=$(command -v sudo)
  else
    cat >&2 <<-'EOF'
Error: this installer needs the ability to run commands as root.
We are unable to find either "sudo" or "su" available to make this happen.
EOF
    exit -1
  fi
fi


DOWNLOAD_URL="https://dc3p1870nn3cj.cloudfront.net/install-wizard-v${VERSION}.tar.gz"

echo ""
echo " Downloading Install-Wizard ${VERSION} from ${DOWNLOAD_URL} ... " 
echo ""

foldername="install-wizard-v${VERSION}"
filename="install-wizard-v${VERSION}.tar.gz"
download_path=$(pwd)

if [ ! -f ${filename} ]; then
  tmpname="install-wizard-v${VERSION}.bak.tar.gz"
  curl -Lo ${tmpname} ${DOWNLOAD_URL}

  if [ $? -ne 0 ] || [ ! -f ${tmpname} ]; then
    echo ""
    echo "Failed to download Install-Wizard ${VERSION} !"
    echo ""
    echo "Please verify the version you are trying to download."
    echo ""
    exit
  fi
  mv ${tmpname} ${filename}
fi

echo ""
echo "Install-Wizard ${VERSION} Download Complete!"
echo ""

if command -v tar >/dev/null; then
    $SUDO rm -rf $HOME/.terminus/${foldername} && \
    mkdir -p $HOME/.terminus/${foldername} && \
    cd $HOME/.terminus/${foldername} && \
    tar -xzf ${download_path}/${filename}

    CLI_VERSION="0.1.13"
    CLI_FILE="terminus-cli-v${CLI_VERSION}_linux_${ARCH}.tar.gz"
    if [ x"${os_type}" == x"Darwin" ]; then
        CLI_FILE="terminus-cli-v${CLI_VERSION}_darwin_${ARCH}.tar.gz"
    fi
    CLI_URL="https://github.com/beclab/Installer/releases/download/${CLI_VERSION}/${CLI_FILE}"

    if [ ! -f ${CLI_FILE} ]; then
        curl -Lo ${CLI_FILE} ${CLI_URL}
    fi

    #TODO: download terminusd and install, set home to env for terminusd

    if [ $? -eq 0 ]; then
        if [[ x"$os_type" == x"Darwin" ]]; then
          cd $HOME/.terminus/${foldername} && \
          bash  ./uninstall_macos.sh && \
          touch $HOME/.terminus/.installed && \
          bash  ./install_macos.sh
        else
          $SUDO -E sh -c "tar -zxvf ${CLI_FILE} && chmod +x terminus-cli && \
          mv terminus-cli /usr/local/bin/terminus-cli"

          cd $HOME/.terminus/${foldername} && \
          bash  ./uninstall_cmd.sh && \
          touch $HOME/.terminus/.installed && \
          bash  ./install_cmd.sh
        fi

        exit 0
    fi
else
    echo "Try to unpack the ${filename} failed."
    echo "tar: command not found, please unpack the ${filename} manually."
    exit 1
fi
