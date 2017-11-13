#!/usr/bin/env bash

base='../deltachat-core'
dst=deltachat-ios/libraries

if [[ ! -d "${base}" ]]; then
    echo Error: deltachat-core repository expected in parent directory
    exit 1
fi

cd "${base}"

if [[ $? -ne 0 ]]; then
    echo Error: could not change to deltachat-core directory
    exit 1
fi

git pull

if [[ $? -ne 0 ]]; then
    echo Error: pulling deltachat-core repository failed
    exit 1
fi

cd -

rm -rf "${dst}"/deltachat-core
mkdir -p "${dst}"
cp -r "${base}" "$dst"
rm -rf "$dst"/deltachat-core/.git*

git_command="git add .; git commit -m 'update core'"
echo "Copied to pasteboard: ${git_command}"
echo -n "${git_command}" | pbcopy

