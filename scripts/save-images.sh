

cat $1|while read image; do
    name=$(echo -n "$image"|md5sum|awk '{print $1}')
    if [ ! -z "$FROM_S3" ]; then
        curl -fsSLI https://dc3p1870nn3cj.cloudfront.net/$name.tar.gz > /dev/null
        if [ $? -ne 0 ]; then
            docker pull $image
            docker save $image -o $name.tar
            gzip $name.tar
        else
            curl -fsSL https://dc3p1870nn3cj.cloudfront.net/$name.tar.gz -o $name.tar.gz
        fi
    else
        docker pull $image
        docker save $image -o $name.tar
        gzip $name.tar
    fi
    echo $name
done