#!/binbash



######## log ########
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
    exit -1
}

######## system ########
get_command() {
    echo $(command -v "$@")
}

command_exists() {
	command -v "$@" > /dev/null 2>&1
}

function dpkg_locked() {
    grep -q 'Could not get lock /var/lib' "$fd_errlog"
    return $?
}

sleep_waiting(){
    local t=$1
    local n=0
    local max_retries=$((t*2))
    while [ $max_retries -gt 0 ]; do
        n=$(expr $n + 1)
        dotn=$(($n % 10))
        dot=$(repeat $dotn '>')

        echo -ne "\rPlease waiting ${dot}"
        sleep 0.5
        echo -ne "\rPlease waiting           "

        ((max_retries--))
    done
    echo
    echo "Continue ... "
}



######## os ########
get_distribution() {
	lsb_dist=""
	# Every system that we officially support has /etc/os-release
	if [ -r /etc/os-release ]; then
		lsb_dist="$(. /etc/os-release && echo "$ID")"
	fi
	echo "$lsb_dist"
}

get_macos_versioin() {
    version=$(sw_vers -productVersion)
    major_version=$(echo "$version" | cut -d '.' -f 1)
    minor_version=$(echo "$version" | cut -d '.' -f 2)
    case "$major_version.$minor_version" in
        10.14.*)
            os_name="Mojave"
            ;;
        10.15.*)
            os_name="Catalina"
            ;;
        11.*)
            os_name="Big Sur"
            ;;
        12.*)
            os_name="Monterey"
            ;;
        13.*)
            os_name="Ventura"
            ;;
        14.*)
            os_name="Sonoma"
            ;;
        *)
            os_name="Unknown"
            ;;
    esac
    echo "$os_name"
}

precheck_support() {
    os_type=$(uname -s)
    case "$os_type" in
        Linux) OSTYPE=linux; ;;
        Darwin) OSTYPE=darwin; ;;
        *) echo "unsupported os type '${os_type}', exit ...";
        exit -1; ;;
    esac

    os_arch=$(uname -m)
    case "$os_arch" in 
        arm64) ARCH=arm64; ;; 
        x86_64) ARCH=amd64; ;; 
        armv7l) ARCH=arm; ;; 
        aarch64) ARCH=arm64; ;; 
        ppc64le) ARCH=ppc64le; ;; 
        s390x) ARCH=s390x; ;; 
        *) echo "unsupported arch '${os_arch}', exit ..."; 
        exit -1; ;; 
    esac

    if [ "$OSTYPE" == "darwin" ]; then
        OSNAME=$(get_macos_versioin)
        OSVERSION=$(sw_vers -productVersion)
    else
        OSNAME=$(. /etc/os-release && echo "$ID")
        OSVERSION=$(. /etc/os-release && echo "$VERSION_ID")
        lsb_release=$(echo "${OSNAME} ${OSVERSION}" | xargs)

        if [ -z "$lsb_release" ]; then
            echo "unsupported os version '${lsb_release}', exit ..."
            exit -1
        fi

        case "$lsb_release" in
            *Debian* | *debian*)
                case "$lsb_release" in
                    *12* | *11*)
                        ;;
                    *)
                        echo "unsupported os version '${lsb_release}', exit ...";
                        exit -1
                        ;;
                esac
                ;;
            *Ubuntu* | *ubuntu*)
                case "$lsb_release" in
                    *24.*)
                        ;;
                    *22.* | *20.*)
                        ;;
                    *)
                        echo "unsupported os version '${lsb_release}', exit ...";
                        exit -1
                        ;;
                esac
                ;;
            *)
                echo "unsupported os version '${lsb_release}', exit ...";
                exit -1
                ;;
        esac
    fi

    echo "$OSTYPE $OSNAME $OSVERSION $ARCH"
}

get_shell_exec() {
    if [ $(is_darwin) -eq 0 ]; then
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
			exit -1
		fi
	fi
    fi
}

get_os_version() {
  echo ${OSVERSION}
}

is_darwin() {
    os_type=$(uname -s 2>&1)
    if [ "$os_type" == "Darwin" ]; then
        echo 1
        return
    fi
    echo 0
}

is_debian() {
    os_name=$(. /etc/os-release && echo "$ID")
    if [ "$os_name" == "debian" ]; then
        echo 1
        return
    fi
    echo 0
}

is_ubuntu() {
    if [ $OSNAME == *ubuntu* ]; then
        echo 1
        return
    fi
    echo 0
}

is_pve() {
    pve=$(uname -a 2>&1)
    pveversion=$(command -v pveversion)
    if [[ ${pve} == *pve* || ! -z $pveversion ]]; then
        echo 1
        return
    fi
    echo 0
}

is_raspbian() {
    rasp=$(uname -a 2>&1)
    if [[ ${rasp} == *Raspbian* || ${rasp} == *raspbian* || ${rasp} == *raspberry* || ${rasp} == *Raspberry* ]];then
        echo 1
        return
    fi
    echo 0
}

is_wsl() {
    wsl=$(uname -a 2>&1)
    if [[ ${wsl} == *WSL* ]]; then
        echo 1
        return
    fi
    echo 0
}

is_k3s(){
	if [ -f /etc/systemd/system/k3s.service ]; then
		return 0
	fi

	return 1
}



######## string ########
get_random_string() {
    local length=12
    local alphanumeric="abc2def3gh4jk5mn6pqr7st8uvw9xyz"

    if [[ -n "$1" && $1 -gt 0 ]]; then
        length=$1
    fi

    local text n
    for ((i=0,l=${#alphanumeric}; i<$length; i++)); do
        n=$[RANDOM%l]
        text+="${alphanumeric:n:1}"
    done
    echo -n "$text"
}