#!/usr/bin/env bash

base='../deltachat-core'
dst=deltachat-ios/libraries
# dst_deltachat_core="${dst}/deltachat-core"

if [[ ! -d "${base}" ]]; then
    echo Error: deltachat-core repository expected in parent directory
    exit 1
fi

rm -rf "${dst}"
mkdir -p "${dst}"
cp -r "${base}" "$dst"
rm -rf "$dst"/deltachat-core/.git*
