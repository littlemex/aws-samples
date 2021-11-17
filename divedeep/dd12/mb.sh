
export BUCKET="comprehendlab-akazawt-`date +%Y%m%d`-$RANDOM"; echo $BUCKET |tee .bucket
aws s3 mb s3://$BUCKET
