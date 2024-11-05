#!/usr/bin/env bash

set -o pipefail
set -xe

# coscli
curl -Lo coscli-v1.0.2-linux-amd64 https://github.com/tencentyun/coscli/releases/download/v1.0.2/coscli-v1.0.2-linux-amd64
curl -Lo coscli-v1.0.2-linux-arm64 https://github.com/tencentyun/coscli/releases/download/v1.0.2/coscli-v1.0.2-linux-arm64

# ossutil
curl -Lo ossutil-v1.7.18-linux-amd64.zip https://github.com/aliyun/ossutil/releases/download/v1.7.18/ossutil-v1.7.18-linux-amd64.zip
curl -Lo ossutil-v1.7.18-linux-arm64.zip https://github.com/aliyun/ossutil/releases/download/v1.7.18/ossutil-v1.7.18-linux-arm64.zip

# awscli
curl -Lo awscli-exe-linux-x86_64.zip https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip

awscli=$(md5sum awscli-exe-linux-x86_64.zip|awk '{print $1}')
cos_amd64=$(md5sum coscli-v1.0.2-linux-amd64|awk '{print $1}')
cos_arm64=$(md5sum coscli-v1.0.2-linux-arm64|awk '{print $1}')
oss_amd64=$(md5sum ossutil-v1.7.18-linux-amd64.zip|awk '{print $1}')
oss_arm64=$(md5sum ossutil-v1.7.18-linux-arm64.zip|awk '{print $1}')

# aws s3 cp redis-5.0.14.tar.gz s3://terminus-os-install/redis-5.0.14_${os}_${arch}.tar.gz --acl=public-read
aws s3 cp awscli-exe-linux-x86_64.zip s3://terminus-os-install/${awscli} --acl=public-read
aws s3 cp coscli-v1.0.2-linux-amd64 s3://terminus-os-install/${cos_amd64} --acl=public-read
aws s3 cp coscli-v1.0.2-linux-arm64 s3://terminus-os-install/${cos_arm64} --acl=public-read
aws s3 cp ossutil-v1.7.18-linux-amd64.zip s3://terminus-os-install/${oss_amd64} --acl=public-read
aws s3 cp ossutil-v1.7.18-linux-arm64.zip s3://terminus-os-install/${oss_arm64} --acl=public-read
