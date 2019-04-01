#!/bin/bash

set -e

OPENSSL_VERSION="openssl-1.1.0j"

IOS_DIST_OUTPUT="./"

IOS_SDK_VERSION=$(xcodebuild -version -sdk iphoneos | grep SDKVersion | cut -f2 -d ':' | tr -d '[[:space:]]')

IOS_DEPLOYMENT_VERSION="7.0"

DEVELOPER=`xcode-select -print-path`

buildIOS()
{
   ARCH=$1

   pushd . > /dev/null
   cd "./${OPENSSL_VERSION}"

   if [[ "${ARCH}" == "i386" || "${ARCH}" == "x86_64" ]]; then
      PLATFORM="iPhoneSimulator"
   else
      PLATFORM="iPhoneOS"
      sed -ie "s!static volatile sig_atomic_t intr_signal;!static volatile intr_signal;!" "crypto/ui/ui_openssl.c"
   fi

   export $PLATFORM
   export CROSS_TOP="${DEVELOPER}/Platforms/${PLATFORM}.platform/Developer"
   export CROSS_SDK="${PLATFORM}${IOS_SDK_VERSION}.sdk"
   export BUILD_TOOLS="${DEVELOPER}"
   export CC="${BUILD_TOOLS}/usr/bin/gcc -mios-version-min=${IOS_DEPLOYMENT_VERSION} -arch ${ARCH}"

   echo "Start Building ${OPENSSL_VERSION} for ${PLATFORM} ${IOS_SDK_VERSION} ${ARCH}"

   echo "Configure"

   FLAGS="no-ssl3"

   if [[ "${ARCH}" == "x86_64" ]]; then
      ./Configure darwin64-x86_64-cc no-asm $FLAGS --prefix="/tmp/${OPENSSL_VERSION}-iOS-${ARCH}" --openssldir="/tmp/${OPENSSL_VERSION}-iOS-${ARCH}" &> "/tmp/${OPENSSL_VERSION}-iOS-${ARCH}.log"
   else
      ./Configure iphoneos-cross $FLAGS --prefix="/tmp/${OPENSSL_VERSION}-iOS-${ARCH}" --openssldir="/tmp/${OPENSSL_VERSION}-iOS-${ARCH}" &> "/tmp/${OPENSSL_VERSION}-iOS-${ARCH}.log"
   fi
   # add -isysroot to CC=
   sed -ie "s!^CFLAG=!CFLAG=-isysroot ${CROSS_TOP}/SDKs/${CROSS_SDK} -mios-version-min=${IOS_DEPLOYMENT_VERSION} !" "Makefile"

   echo "make"
   make >> "/tmp/${OPENSSL_VERSION}-iOS-${ARCH}.log" 2>&1
   echo "make install"
   make install_sw >> "/tmp/${OPENSSL_VERSION}-iOS-${ARCH}.log" 2>&1
   echo "make clean"
   make clean  >> "/tmp/${OPENSSL_VERSION}-iOS-${ARCH}.log" 2>&1
   popd > /dev/null

   echo "Done Building ${OPENSSL_VERSION} for ${PLATFORM} ${IOS_SDK_VERSION} ${ARCH}"
}

echo "Cleaning up"

mkdir -p ${IOS_DIST_OUTPUT}/lib
mkdir -p ${IOS_DIST_OUTPUT}/include/openssl/

rm -rf "/tmp/${OPENSSL_VERSION}-*"
rm -rf "/tmp/${OPENSSL_VERSION}-*.log"

rm -rf "${OPENSSL_VERSION}"

if [ ! -e ${OPENSSL_VERSION}.tar.gz ]; then
   echo "Downloading ${OPENSSL_VERSION}.tar.gz"
   curl -O https://www.openssl.org/source/${OPENSSL_VERSION}.tar.gz
else
   echo "Using ${OPENSSL_VERSION}.tar.gz"
fi

echo "Unpacking openssl"
tar xfz "${OPENSSL_VERSION}.tar.gz"

echo "----------------------------------------"
echo "OpenSSL version: ${OPENSSL_VERSION}"
echo "iOS SDK version: ${IOS_SDK_VERSION}"
echo "iOS deployment target: ${IOS_DEPLOYMENT_VERSION}"
echo "----------------------------------------"
echo " "

buildIOS "armv7"
buildIOS "arm64"
buildIOS "x86_64"
buildIOS "i386"

echo "Copying iOS headers"
cp /tmp/${OPENSSL_VERSION}-iOS-arm64/include/openssl/* ${IOS_DIST_OUTPUT}/include/openssl/

echo "Building iOS libraries"
lipo \
   "/tmp/${OPENSSL_VERSION}-iOS-armv7/lib/libcrypto.a" \
   "/tmp/${OPENSSL_VERSION}-iOS-arm64/lib/libcrypto.a" \
   "/tmp/${OPENSSL_VERSION}-iOS-i386/lib/libcrypto.a" \
   "/tmp/${OPENSSL_VERSION}-iOS-x86_64/lib/libcrypto.a" \
   -create -output ${IOS_DIST_OUTPUT}/lib/libcrypto.a

lipo \
   "/tmp/${OPENSSL_VERSION}-iOS-armv7/lib/libssl.a" \
   "/tmp/${OPENSSL_VERSION}-iOS-arm64/lib/libssl.a" \
   "/tmp/${OPENSSL_VERSION}-iOS-i386/lib/libssl.a" \
   "/tmp/${OPENSSL_VERSION}-iOS-x86_64/lib/libssl.a" \
   -create -output ${IOS_DIST_OUTPUT}/lib/libssl.a

echo "Cleaning up"
rm -rf /tmp/${OPENSSL_VERSION}-*
rm -rf ${OPENSSL_VERSION}

echo "Done"
