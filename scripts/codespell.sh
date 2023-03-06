#!/bin/sh
codespell \
  --skip './.git,./Pods,./deltachat-ios/Assets,Localizable.strings,Localizable.stringsdict,InfoPlist.strings,./deltachat-ios/libraries/deltachat-core-rust' \
  --ignore-words-list curveLinear
