#!/bin/bash

curl -X POST \
  http://localhost:8000/remove-background \
  -F "file=@./examples/anime-girl-3.jpg" \
  -F "model=isnet-general-use" \
  -o ./outputs/rm-anime-girl-3.png