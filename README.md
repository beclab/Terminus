# Terminus OS

Terminus OS is a free, source-available cloud-native operating system based on Kubernetes, designed for both individuals and enterprises.

## Introduction

With the development of AI, people are increasingly concerned about their privacy.

Terminus OS helps individuals and enterprises manage their data, operations, and lifestyles effectively:

- For users, we hope that people can use Terminus OS as easily as they use their smartphones.
- For developers, we aim to provide an experience consistent with that of public clouds.

We understand the difficulty of achieving these goals. However, over the past decade, the development of cloud-native technologies, spearheaded by Kubernetes, has made it feasible for individual users to manage a small server cluster with the necessary time and skills becoming increasingly accessible.

Terminus OS development incorporates numerous third-party projects, including: [Kubernetes](https://kubernetes.io/), [Kubesphere](https://github.com/kubesphere/kubesphere), [Padloc](https://padloc.app/), [K3S](https://k3s.io/), [JuiceFS](https://github.com/juicedata/juicefs), [MinIO](https://github.com/minio/minio), [Envoy](https://github.com/envoyproxy/envoy), [Authelia](https://github.com/authelia/authelia), [Infisical](https://github.com/Infisical/infisical), [Dify](https://github.com/langgenius/dify), [Seafile](https://github.com/haiwen/seafile).

## Directory structure
```
terminus
|-- apps                  # terminus built-in apps
|   |-- agent
|   |-- analytic
|   |-- market
|   |-- market-server
|   |-- argo
|   |-- desktop
|   |-- devbox
|   |-- vault
|   |-- files
|   |-- knowledge
|   |-- nitro
|   |-- notifications
|   |-- profile
|   |-- rss
|   |-- search
|   |-- settings
|   |-- system-apps
|   |-- wise
|   |-- wizard
|-- build                 # terminus installer 
|   |-- installer
|   |-- manifest
|-- frameworks            # system runtime frameworks
|   |-- app-service
|   |-- backup-server
|   |-- bfl
|   |-- GPU
|   |-- l4-bfl-proxy
|   |-- osnode-init
|   |-- system-server
|   |-- tapr
|-- libs                  # toolkit libs
|   |-- fs-lib
|-- scripts               # scripts for build or package the terminus installer
|-- third-party           # third party libs or apps integrated in terminus
|   |-- authelia
|   |-- headscale
|   |-- infisical
|   |-- juicefs
|   |-- ks-console
|   |-- ks-installer
|   |-- kube-state-metrics
|   |-- notification-mananger
|   |-- predixy
|   |-- redis-cluster-operator
|   |-- seafile-server
|   |-- seahub
|   |-- tailscale
```

## How to install
```
curl -fsSL https://terminus.sh |  bash -
```

## How to build

```
git clone https://github.com/beclab/terminus.git

cd terminus-os

bash scripts/build.sh

```
Run the above scripts, you will get the debug version installer package `install-wizard-debug.tar.gz`


## How to install debug version
```
mkdir -p /path/to/unpack && cd /path/to/unpack

tar zxvf /path/to/terminus-os/install-wizard-debug.tar.gz

make install VERSION=0.0.0-DEBUG

```

## How to uninstall
```
cd /path/to/terminus && make uninstall

```