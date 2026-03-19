#!/bin/sh

set -euxo pipefail

# Go to the project folder
cd ..

export RUSTUP_DIST_SERVER=https://mirrors.ustc.edu.cn/rust-static
export RUSTUP_UPDATE_ROOT=https://mirrors.ustc.edu.cn/rust-static/rustup
# Install [rustup](https://rustup.rs)
curl https://sh.rustup.rs -sSf | sh -s -- -y

# Make sure the correct rust version is installed
rustup toolchain install `cat rust-toolchain`
rustup default $(cat rust-toolchain)

source $HOME/.cargo/env

# Install [cargo-lipo](https://github.com/TimNN/cargo-lipo#installation)
cargo install cargo-lipo

# Note: CocoaPods is pre-installed on Xcode Cloud

# Download chatmail/core
git submodule update --init --recursive

pod install
