#!/bin/sh

set -euxo pipefail

# Go to the project folder
cd ..

# Install [rustup](https://rustup.rs)
brew install -q rustup

# Make sure the correct rust version is installed
rustup toolchain install `cat rust-toolchain`
rustup default $(cat rust-toolchain)
source $HOME/.cargo/env

# Install [cargo-lipo](https://github.com/TimNN/cargo-lipo#installation)
rustup run cargo install cargo-lipo

# Note: CocoaPods is pre-installed on Xcode Cloud

# Download chatmail/core
git submodule update --init --recursive

pod install
