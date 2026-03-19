#!/bin/sh

# Install [rustup](https://rustup.rs)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Install [cargo-lipo](https://github.com/TimNN/cargo-lipo#installation)
cargo install cargo-lipo

# Note: CocoaPods is pre-installed on Xcode Cloud

# Setup workspace
git submodule update --init --recursive

# Make sure the correct rust version is installed
rustup toolchain install `cat rust-toolchain`

pod install
