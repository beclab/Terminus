#!/bin/bash
source ./common.sh

precheck_support
get_shell_exec

CLI_VERSION="0.1.13"
CLI_FILENAME="terminus-cli-v${CLI_VERSION}_darwin_${ARCH}.tar.gz"
CLI_URL="https://github.com/beclab/Installer/releases/download/${CLI_VERSION}/terminus-cli-v${CLI_VERSION}_darwin_${ARCH}.tar.gz"


cli_tar="terminus-cli-v${CLI_VERSION}_darwin_${ARCH}.tar.gz"
if [ ! -f "${CLI_FILENAME}" ]; then
    curl -Lo ${CLI_FILENAME} ${CLI_URL}
fi
tar xvf terminus-cli-v${CLI_VERSION}_darwin_${ARCH}.tar.gz; chmod +x terminus-cli

./terminus-cli terminus uninstall --minikube