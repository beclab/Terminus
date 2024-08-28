#!/usr/bin/env bash
source ./common.sh


set -o pipefail
set -e

export VERSION="#__VERSION__"
if [ "x${VERSION}" = "x" ]; then
  echo "Unable to get latest Install-Wizard version. Set VERSION env var and re-run. For example: export VERSION=1.0.0"
  echo ""
  exit
fi

# check os type and arch and os vesion
precheck_os
get_shell_exec

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
    $sh_c "rm -rf $HOME/.terminus/${foldername} && \
    mkdir -p $HOME/.terminus/${foldername} && \
    cd $HOME/.terminus/${foldername} && \
    tar -xzf ${download_path}/${filename}"

    CLI_VERSION="0.1.13"
    CLI_FILE="terminus-cli-v${CLI_VERSION}_linux_${ARCH}.tar.gz"
    if [ $(is_darwin) -eq 1 ]; then
        CLI_FILE="terminus-cli-v${CLI_VERSION}_darwin_${ARCH}.tar.gz"
    fi
    CLI_URL="https://github.com/beclab/Installer/releases/download/${CLI_VERSION}/${CLI_FILE}"

    if [ ! -f ${CLI_FILE} ]; then
        curl -Lo ${CLI_FILE} ${CLI_URL}
    fi

    #TODO: download terminusd and install, set home to env for terminusd

    if [ $? -eq 0 ]; then
        if [[ $(is_darwin) -eq 1 ]]; then
          $sh_c "cd $HOME/.terminus/${foldername} && \
          bash  ./uninstall_macos.sh && \
          touch $HOME/.terminus/.installed && \
          bash  ./install_macos.sh"
        else
          $sh_c "tar -zxvf ${CLI_FILE} && chmod +x terminus-cli && \
          mv terminus-cli /usr/local/bin/terminus-cli"

          $sh_c "cd $HOME/.terminus/${foldername} && \
          bash  ./uninstall_cmd.sh && \
          touch $HOME/.terminus/.installed && \
          bash  ./install_cmd.sh"
        fi

        exit 0
    fi
else
    echo "Try to unpack the ${filename} failed."
    echo "tar: command not found, please unpack the ${filename} manually."
    exit 1
fi
