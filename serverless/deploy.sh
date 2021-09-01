#!/bin/sh

# arg parse
[[ $1 == '' ]] && echo "please input $1(prod or stg, dev)" && exit 1
[[ $1 == 'prod' ]] && echo prod && next=1 && xenv='prod'
[[ $1 == 'stg' ]] && echo stg && next=1 && xenv='stg'
[[ $1 == 'dev' ]] && echo dev && next=1 && xenv='dev'
[[ $next -eq 0 ]] && echo "please input $1(prod or stg, dev)" && exit 1

rm -rf ./.serverless
npm install

# exec serverless
serverless deploy -c ./serverless_${xenv}.yml

echo "finished!!"