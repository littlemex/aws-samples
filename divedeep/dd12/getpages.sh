#!/bin/bash

for m in `cat aws.txt`
do 
  echo "Getting https://en.wikipedia.org/wiki/${m}"
  curl "https://en.wikipedia.org/wiki/${m}" > "Data/${m}.html"
done
