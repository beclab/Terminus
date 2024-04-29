#!/usr/bin/env bash



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

get_shell_exec

$sh_c 'apt-get --purge remove -y  "*cublas*" "*cufft*" "*curand*" "*cusolver*" "*cusparse*" "*npp*" "*nvjpeg*" "cuda*" "nsight*"'
$sh_c 'apt-get --purge remove -y "*nvidia*"'
$sh_c 'apt-get autoremove -y'