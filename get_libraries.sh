#!/usr/bin/env bash

base='../deltachat-core'
dst=deltachat-ios/libraries

if [[ ! -d "${base}" ]]; then
    echo Error: deltachat-core repository expected in parent directory
    exit 1
fi

rm -rf "${dst}"/deltachat-core
mkdir -p "${dst}"
cp -r "${base}" "$dst"
rm -rf "$dst"/deltachat-core/.git*
