#!/usr/bin/env bash
ERR_EXIT=-1

log_info() {
    local msg now

    msg="$*"
    now=$(date +'%Y-%m-%d %H:%M:%S.%N %z')
    echo -e "\n\033[38;1m${now} [INFO] ${msg} \033[0m" 
}

log_fatal() {
    local msg now

    msg="$*"
    now=$(date +'%Y-%m-%d %H:%M:%S.%N %z')
    echo -e "\n\033[31;1m${now} [FATAL] ${msg} \033[0m" 
    exit $ERR_EXIT
}

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

	KUBECTL=$(command -v kubectl)
}

ensure_success() {
    "$@"
    local ret=$?

    if [ $ret -ne 0 ]; then
        echo "Fatal error, command: '$*'"
        exit $ret
    fi

    return $ret
}

system_service_active() {
    if [[ $# -ne 1 || x"$1" == x"" ]]; then
        return 1
    fi

    local ret
    ret=$($sh_c "systemctl is-active $1")
    if [ "$ret" == "active" ]; then
        return 0
    fi
    return 1
}

precheck_os() {
    # try to resolv hostname
    ensure_success $sh_c "hostname -i >/dev/null"

    local ip=$(ping -c 1 "$HOSTNAME" |awk -F '[()]' '/icmp_seq/{print $2}')
    printf "%s\t%s\n\n" "$ip" "$HOSTNAME"

    if [[ x"$ip" == x"" || "$ip" == @("172.17.0.1"|"127.0.0.1"|"127.0.1.1") || ! "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log_fatal "incorrect ip for hostname '$HOSTNAME', please check"
    fi

	read -r -p "Are you sure changing this node ip to ${ip}? [yes/no]: " ans </dev/tty

    if [ x"$ans" != x"yes" ]; then
		echo "Please edit /etc/hosts to add the correct node IP"
        echo "exiting..."
        exit
    fi

    local_ip="$ip"
}

regen_cert_conf(){
	for pem in $1 ; do
	echo -e "[ req ]\ndefault_bits\t= 4096\ndistinguished_name\t= req_distinguished_name\nreq_extensions\t= v3_ext\nprompt\t= no\n[ req_distinguished_name ]" ; 
	IFS="," 

		for att in `openssl x509 -in $pem -text -noout | grep Subject: | cut -d: -f2 ` ;  

			do VALUE=`echo $att | cut -d= -f2-9 `; 
				case $att in 
				\ C\ =*) echo "countryName_default = $VALUE" ;; 
				\ ST\ =*) echo "StateOrProvinceName_default = $VALUE" ;; 
				\ L\ =*) echo "localityName_default = $VALUE";; 
				\ O\ =*) echo "organizationName_default = $VALUE" ;; 
				\ OU\ =*)  echo "organizationUnitName_default = $VALUE" ;; 
				\ CN\ =*)  echo "commonName = $VALUE" ;; 
			esac 
		done

			openssl x509 -in $pem -text | grep -A1 Subject\ Alternative\ Name | tail -1 | xargs echo -e "[ v3_ext ]\nsubjectAltName = "|sed -e 's/IP Address/IP/g'
	done
}




update_juicefs() {
	ensure_success $sh_c "systemctl stop juicefs minio minio-operator redis-server"

	local TERMINUS_ROOT="/terminus"
    local fsname="rootfs"

	# update redis
	local redis_root="${TERMINUS_ROOT}/data/redis"
    local redis_conf="${redis_root}/etc/redis.conf"

	# TODO: get old ip
	old_ip=$($sh_c "awk '/bind/{print \$NF}' $redis_conf")
	while [ -z "$old_ip" ]; do
		read -r -p "Cannot find the previous IP, please input: " old_ip </dev/tty
	done

	echo "the previous IP is $old_ip"

	ensure_success $sh_c "sed -i 's/$old_ip/$local_ip/g' /etc/hosts"

	ensure_success $sh_c "sed -i 's/bind [0-9.]*/bind $local_ip/g' $redis_conf"
	
	ensure_success $sh_c "systemctl start redis-server"

    # eusure redis is started
    ensure_success $sh_c "( sleep 10 && systemctl --no-pager status redis-server ) || \
    ( systemctl restart redis-server && sleep 3 && systemctl --no-pager status redis-server ) || \
    ( systemctl restart redis-server && sleep 3 && systemctl --no-pager status redis-server )"

    local REDIS_PASSWORD=$($sh_c "awk '/requirepass/{print \$NF}' $redis_conf")
    if [ x"$REDIS_PASSWORD" == x"" ]; then
        echo "no redis password found in $redis_conf"
        exit $ERR_EXIT
    fi

    log_info 'try to connect redis'

    local pong=$(/usr/bin/redis-cli -h "$local_ip" -a "$REDIS_PASSWORD" ping 2>/dev/null)
    if [ x"$pong" != x"PONG" ]; then
        echo "failed to connect redis server: ${local_ip}:6379"
        exit $ERR_EXIT
    fi

	log_info 'update redis IP success'

	# update minio and minio-operator
	local MINIO_ROOT_USER=""
	local MINIO_ROOT_PASSWORD=""
	if [ -f /etc/default/minio ]; then
		log_info 'updating minio'

		ensure_success $sh_c "sed -i 's/$old_ip/$local_ip/g' /etc/default/minio"

		ensure_success $sh_c "systemctl start minio"
		# postpone restart minio-operator, until etcd restarted

	    # ensure minio is ready
		local max_retry=60
		local ok="n"
		while [ $max_retry -ge 0 ]; do
			if $sh_c 'systemctl --no-pager status minio >/dev/null'; then
				ok=y
				break
			fi
			sleep 5
			((max_retry--))
		done

		if [ x"$ok" != x"y" ]; then
			echo "minio is not ready yet, please check it"
			exit $ERR_EXIT
		fi

		log_info 'update minio IP success'

		storage_type="minio"
		MINIO_ROOT_USER="minioadmin"
		MINIO_ROOT_PASSWORD=$(awk -F '=' '/^MINIO_ROOT_PASSWORD/{print $2}' /etc/default/minio)
	fi


	# update juicefs
	local jfs_mountpoint="${TERMINUS_ROOT}/${fsname}"

	log_info 'updating juicefs'
	ensure_success $sh_c "sed -i 's/$old_ip/$local_ip/g' /etc/systemd/system/juicefs.service"

	ensure_success $sh_c "systemctl daemon-reload"
	ensure_success $sh_c "systemctl start juicefs"

	if [ "$storage_type" == "minio" ]; then
	    local juicefs_bin="/usr/local/bin/juicefs"
		local bucket="terminus"
		local metadb="redis://:${REDIS_PASSWORD}@${local_ip}:6379/1"

        ensure_success $sh_c "$juicefs_bin config $metadb --bucket http://${local_ip}:9000/${bucket} --access-key $MINIO_ROOT_USER --secret-key $MINIO_ROOT_PASSWORD"
	fi

	ensure_success $sh_c "systemctl --no-pager status juicefs"
    ensure_success $sh_c "sleep 3 && test -d $jfs_mountpoint/.trash"

	log_info 'update juicefs IP success'
}

update_minio_operator(){
	local MINIO_ROOT_PASSWORD=$(awk -F '=' '/^MINIO_ROOT_PASSWORD/{print $2}' /etc/default/minio)
	local MINIO_VOLUMES=$(awk -F '=' '/^MINIO_VOLUMES/{print $2}' /etc/default/minio)

	# re-init minio-operator, only used for uninitialized master node machine
	local ETCDCTL=$(command -v etcdctl)
	local minio_operator_bin="/usr/local/bin/minio-operator"

	# clear minio-operator service
	ensure_success $sh_c "rm -f /etc/default/minio-operator /etc/systemd/system/minio-operator.service"
	ensure_success $sh_c "$ETCDCTL --cacert /etc/ssl/etcd/ssl/ca.pem --cert /etc/ssl/etcd/ssl/node-$HOSTNAME.pem --key /etc/ssl/etcd/ssl/node-$HOSTNAME-key.pem del terminus/minio --prefix"

    ensure_success $sh_c "$minio_operator_bin init --address $local_ip --cafile /etc/ssl/etcd/ssl/ca.pem --certfile /etc/ssl/etcd/ssl/node-$HOSTNAME.pem --keyfile /etc/ssl/etcd/ssl/node-$HOSTNAME-key.pem --volume $MINIO_VOLUMES --password $MINIO_ROOT_PASSWORD"

	log_info "update minio-operator success"
}

update_k3s_master() {
	ensure_success $sh_c "$KUBECTL delete node $HOSTNAME"

	ensure_success $sh_c "systemctl stop k3s etcd"
}

post_update_k3s_master(){
	ensure_success $sh_c "sed -i 's/$old_ip/$local_ip/g' /etc/systemd/system/k3s.service"
	ensure_success $sh_c "sed -i 's/$old_ip/$local_ip/g' /etc/systemd/system/k3s.service.env"
	ensure_success $sh_c "sed -i 's/$old_ip/$local_ip/g' /etc/etcd.env"
	ensure_success $sh_c "sed -i 's/$old_ip/$local_ip/g' /usr/local/bin/kube-scripts/etcd-backup.sh"

	# renew etcd cert
	local tmpdir=$(mktemp -d)
	ensure_success $sh_c "mv /etc/ssl/etcd/ssl/* $tmpdir/."
	ensure_success $sh_c "cp $tmpdir/{ca.pem, ca-key.pem} /etc/ssl/etcd/ssl/."
	local confile = "$tmpdir/cert.conf"
	ensure_success regen_cert_conf $tmpdir/admin-$HOSTNAME.pem > $confile

	for instance in admin-$HOSTNAME member-$HOSTNAME node-$HOSTNAME; do
		ensure_success $sh_c "openssl req -newkey rsa:2048 -nodes \
             -keyout /etc/ssl/etcd/ssl/${instance}-key.pem \
             -config ${confile} \
             -out /etc/ssl/etcd/ssl/${instance}-cert.csr"

		ensure_success $sh_c "openssl x509 -req \
             -extfile ${confile} \
             -extensions v3_ext \
             -in /etc/ssl/etcd/ssl/${instance}-cert.csr \
             -CA /etc/ssl/etcd/ssl/ca.pem \
             -CAkey /etc/ssl/etcd/ssl/ca-key.pem \
             -CAcreateserial \
             -out /etc/ssl/etcd/ssl/${instance}.pem \
             -days 3650 -sha256"
	done


    ensure_success $sh_c "systemctl daemon-reload"
	ensure_success $sh_c "systemctl start etcd"
	ensure_success $sh_c "systemctl start k3s"
	ensure_success $sh_c "systemctl --no-pager status k3s"
}

update_k8s_master() {
	ensure_success $sh_c "systemctl stop kubelet containerd"

	cd /etc/
	local KUBEADM=$(command -v kubeadm)

	# backup old kubernetes data
	tmpdir=$(mktemp -d)
	ensure_success $sh_c "mv kubernetes $tmpdir/kubernetes-backup"
	ensure_success $sh_c "mv /var/lib/kubelet $tmpdir/kubelet-backup"

	# restore certificates
	ensure_success $sh_c "mkdir -p kubernetes"
	ensure_success $sh_c "cp -r $tmpdir/kubernetes-backup/pki kubernetes"
	ensure_success $sh_c "rm -rf kubernetes/pki/{apiserver.*,etcd/peer.*}"

	ensure_success $sh_c "systemctl start containerd"

	# reinit master with data in etcd
	# add --kubernetes-version, --pod-network-cidr and --token options if needed
	ensure_success $sh_c "$KUBEADM init \ 
		--ignore-preflight-errors=DirAvailable--var-lib-etcd,Port-10259,Port-10257 \
		--skip-phases=addon/coredns,addon/kube-proxy"

	# update kubectl config
	ensure_success $sh_c "cp kubernetes/admin.conf /root/.kube/config"

	# wait for some time and delete old node
	sleep 120
	ensure_success $sh_c "$KUBECTL get nodes --sort-by=.metadata.creationTimestamp"
	ensure_success $sh_c "$KUBECTL delete node $($KUBECTL get nodes -o jsonpath='{.items[?(@.status.conditions[0].status==\"Unknown\")].metadata.name}')"

	# check running pods
	ensure_success $sh_c "$KUBECTL get pods --all-namespaces"
}

main() {
	get_shell_exec
	precheck_os

	local storage_type="s3"
	if system_service_active "k3s" ; then
		update_k3s_master
	fi 

	update_juicefs

	if system_service_active "k3s" ; then
		post_update_k3s_master
	else
	    update_k8s_master
	fi 

	if [ "$storage_type" == "minio" ]; then 
		update_minio_operator
	fi
}

main
