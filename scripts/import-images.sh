

cat $1|while read image; do
    name=$(echo -n "$image"|md5sum|awk '{print $1}')
    gunzip $name.tar.gz
    docker load -i $name.tar 
    echo "$image $name"
done