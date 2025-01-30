#!/bin/sh
set -e

export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export PATH="$HOME/.cargo/bin:$PATH"

FILENAME="libdeltachat.a"
DIR="../deltachat-ios/libraries"

# Delete old build, if any.
rm -f "${DIR}/${FILENAME}"

rustc `cat ../rust-toolchain` --version

# ensure all targets are installed
rustup target add aarch64-apple-ios x86_64-apple-ios --toolchain `cat ../rust-toolchain`

# --xcode-integ determines --release and --targets from Xcode's env vars.
# Depending your setup, specify the rustup toolchain explicitly.
#
# --no-sanitize-env prevents removal of IPHONEOS_DEPLOYMENT_TARGET variable.
CARGO_PROFILE_RELEASE_LTO=true \
CARGO_PROFILE_DEV_LTO=true \
RUSTFLAGS="-C embed-bitcode=yes" \
  cargo +`cat ../rust-toolchain` lipo --xcode-integ --no-sanitize-env --manifest-path "$DIR/deltachat-core-rust/deltachat-ffi/Cargo.toml"

# cargo-lipo drops result in different folder, depending on the config.
if [[ $CONFIGURATION = "Debug" ]]; then
  SOURCE="$DIR/deltachat-core-rust/target/universal/debug/${FILENAME}"
else
  SOURCE="$DIR/deltachat-core-rust/target/universal/release/${FILENAME}"
fi

# Copy compiled library to DIR.
if [ -e "${SOURCE}" ]; then
  cp -a "${SOURCE}" $DIR
fi
