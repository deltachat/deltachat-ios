#!/bin/sh

# Go to the project folder
cd ..

# Install [rustup](https://rustup.rs)
brew install rustup

# Make sure the correct rust version is installed
rustup toolchain install `cat rust-toolchain`

# Install [cargo-lipo](https://github.com/TimNN/cargo-lipo#installation)
cargo install cargo-lipo

# Note: CocoaPods is pre-installed on Xcode Cloud

# Download chatmail/core
git submodule update --init --recursive

pod install
