#!/usr/bin/env bash


CURL_TRY="--connect-timeout 30 --retry 5 --retry-delay 1 --retry-max-time 10 "

usage() { echo "Usage: $0 [-u <master node ssh user>] [-a <driver|node>] [-s <master node ip>] [-n <node ip>] [-v <volumes>]" 1>&2; exit 1; }

command_exists() {
	command -v "$@" > /dev/null 2>&1
}

get_shell_exec(){
    user="$(id -un 2>/dev/null || true)"

    sh_c='sh -c'
	if [ "$user" != 'root' ]; then
		if command_exists sudo && command_exists su; then
			sh_c='sudo su -c'
		else
			cat >&2 <<-'EOF'
			Error: this installer needs the ability to run commands as root.
			We are unable to find either "sudo" or "su" available to make this happen.
			EOF
			exit $ERR_EXIT
		fi
	fi
}

function ensure_success() {
    "$@"
    local ret=$?

    if [ $ret -ne 0 ]; then
        echo "Fatal error, command: '$*'"
        exit $ret
    fi

    return $ret
}


copy_keyfiles(){
    local master=$1
    if [ -z "$master" ]; then
        echo "master node is not provided" > 2
        exit -1
    fi

    local user=""
    if [ ! -z "$MASTER_USER" ]; then
        user="${MASTER_USER}@"
    fi

    ensure_success rm -rf /tmp/keyfiles && mkdir /tmp/keyfiles
    ensure_success scp $user$master:/etc/ssl/etcd/ssl/ca.pem /tmp/keyfiles/.
    ensure_success scp $user$master:/etc/ssl/etcd/ssl/node-*.pem /tmp/keyfiles/.
    ensure_success $sh_c "mkdir -p /etc/ssl/etcd/ssl"
    ensure_success $sh_c "cp /tmp/keyfiles/* /etc/ssl/etcd/ssl/."
}

install_minio() {
    MINIO_VERSION="RELEASE.2023-05-04T21-44-30Z"
    log_info 'start to install minio'

    local minio_bin="/usr/local/bin/minio"

    if [ ! -f "$minio_bin" ]; then
        ensure_success $sh_c "curl ${CURL_TRY} -kLo minio https://dl.min.io/server/minio/release/linux-amd64/archive/minio.${MINIO_VERSION}"
        ensure_success $sh_c "chmod +x minio"
        ensure_success $sh_c "install minio /usr/local/bin"
    fi

    $sh_c "groupadd -r minio >/dev/null; true"
    $sh_c "useradd -M -r -g minio minio >/dev/null; true"
}

install_minio_operator(){
    MINIO_OPERATOR_VERSION="v0.0.1"
    MINIO_OPERATOR="/usr/local/bin/minio-operator"

    if [ ! -f "$MINIO_OPERATOR" ]; then
        ensure_success $sh_c "curl ${CURL_TRY} -k -sfLO https://github.com/beclab/minio-operator/releases/download/${MINIO_OPERATOR_VERSION}/minio-operator-${MINIO_OPERATOR_VERSION}-linux-amd64.tar.gz"
	    ensure_success $sh_c "tar zxf minio-operator-${MINIO_OPERATOR_VERSION}-linux-amd64.tar.gz"
        ensure_success $sh_c "install -m 755 minio-operator $MINIO_OPERATOR"
    fi
}

while getopts ":a:s:n:v:" o; do
    case "${o}" in
        u)
            u=${OPTARG}
            ;;
        a)
            a=${OPTARG}
            ;;
        s)
            s=${OPTARG}
            ;;
        n)
            n=${OPTARG}
            ;;
        v)
            v=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

if [ -z "${a}" ]  || [ -z "${v}" ]; then
    usage
fi

if ["x$a" != "xnode" ] || ["x$a" != "xdriver" ]; then
    usage
fi    

if [[ "x$a" == "xnode"  && ( -z "$n"  ||  -z "${s}" ) ]] ; then
    echo "master ip or node ip is not provided"
    usage
fi

set -eo pipefail

ACTION="$a"
MASTER_NODE="$s"
NODE="$n"
VOLUMES="$v"

if [ ! -z "${u}" ]; then
    MASTER_USER="${u}"
fi

get_shell_exec

copy_keyfiles "${MASTER_NODE}"

install_minio

install_minio_operator

ETCD_CAFILE="/etc/ssl/etcd/ssl/ca.pem"
ETCD_CERTFILE=$(find /etc/ssl/etcd/ssl/ -type f -name node-*.pem|grep -v key)
ETCD_KEYFILE=$(find /etc/ssl/etcd/ssl/ -type f -name node-*.pem|grep key)
ETCD_SERVER="${MASTER_NODE}:2379"

args="--cafile ${ETCD_CAFILE} --certfile ${ETCD_CERTFILE} --keyfile ${ETCD_KEYFILE} --volume ${VOLUMES}"

if [ "x$ACTION" == "xnode" ]; then
    args+=" --server ${ETCD_SERVER} --address ${NODE}"
fi

ensure_success $sh_c "$MINIO_OPERATOR add $ACTION $args"