#!/usr/bin/env bash

exec ffmpeg \
    -y \
    -i "$1" \
    -map 0:v \
    -map 0:a:m:default:1? \
    -map -0:a:m:language:eng? \
    -map 0:a:m:language:eng? \
    -map -0:a:m:language:und? \
    -map 0:a:m:language:und? \
    -map 0:s:m:language:eng? \
    -map 0:d? \
    -map 0:t? \
    -map_metadata 0 \
    -c:v libx265 -crf 18 -preset medium \
    -c:a copy \
    -c:s copy \
    "$2"
