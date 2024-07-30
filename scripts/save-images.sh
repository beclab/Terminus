PLATFORM=${2:-linux/amd64}
path=""
if [ x"$PLATFORM" == x"linux/arm64" ]; then
    path="arm64/"
fi

function retry_cmd(){
    "$@"
    local ret=$?
    if [ $ret -ne 0 ];then
        local max_retries=5
        local delay=3
        while [ $max_retries -gt 0 ]; do
            printf "retry to execute command '%s', after %d seconds\n" "$*" $delay
            ((delay+=2))
            sleep $delay

            "$@"
            ret=$?
            
            if [[ $ret -eq 0 ]]; then
                break
            fi
            
            ((max_retries--))

        done
    fi

    return $ret
}

cat $1|while read image; do
    name=$(echo -n "$image"|md5sum|awk '{print $1}')
    if [ ! -z "$FROM_S3" ]; then
        curl -fsSLI https://dc3p1870nn3cj.cloudfront.net/$path$name.tar.gz > /dev/null
        if [ $? -ne 0 ]; then
            # docker pull $image --platform $PLATFORM
            # docker save $image -o $name.tar

            reg=$(echo "$image"|awk -F "/" '{print $1}')
            if [[ "$reg" != "registry.k8s.io" && "$reg" != "k8s.gcr.io" ]]; then
                image=$(echo "$image"|awk -F"/" '{if(NF==1)print "docker.io/library/"$0;else if(NF==2)print "docker.io/"$0;else print $0}')
            fi

            if retry_cmd ctr i pull --platform $PLATFORM $image ; then
                ctr i export --platform $PLATFORM $name.tar $image

                gzip $name.tar
            fi
        else
            curl -fsSL https://dc3p1870nn3cj.cloudfront.net/$path$name.tar.gz -o $name.tar.gz
        fi
    else
        # docker pull $image --platform $PLATFORM
        # docker save $image -o $name.tar

        reg=$(echo "$image"|awk -F "/" '{print $1}')
        if [[ "$reg" != "registry.k8s.io" && "$reg" != "k8s.gcr.io" ]]; then
          image=$(echo "$image"|awk -F"/" '{if(NF==1)print "docker.io/library/"$0;else if(NF==2)print "docker.io/"$0;else print $0}')
        fi

        if retry_cmd ctr i pull --platform $PLATFORM $image ; then
            ctr i export --platform $PLATFORM $name.tar $image

            gzip $name.tar
        fi
    fi
    echo $name
done