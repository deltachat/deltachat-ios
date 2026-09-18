#!/bin/zsh

# Xcode 27 no longer allows installing to devices before iOS 17
# so you can use this script to install to those devices instead.
# - Install airdrop-cli on mac (brew install --HEAD vldmrkl/formulae/airdrop-cli)
# - Install trollstore on iPhone/iPad (https://ios.cfw.guide/installing-trollstore/)
# - Build with Xcode
# - Run this script

APP=`find ~/Library/Developer/Xcode/DerivedData \
-name "deltachat-ios.app" \
-path "*Products/Debug-iphoneos/*" \
-not -path "*.noindex/*" \
-print -quit`

echo "Using: $APP"
mkdir Payload
cp -R "$APP" Payload/
zip -r deltachat-ios.ipa Payload
rm -rf Payload
airdrop deltachat-ios.ipa
rm deltachat-ios.ipa
