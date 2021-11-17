#!/bin/bash

for m in `cat aws.txt`
do 
  echo "Getting https://ja.wikipedia.org/wiki/${m}"
  curl "https://ja.wikipedia.org/wiki/${m}" > "Data/${m}.html"
done
