../deltachat-pages/tools/create-local-help.py ../deltachat-pages/result deltachat-ios/Assets/Help --add-top-links

rm -r deltachat-ios/Assets/Help/zh-Hant
mv deltachat-ios/Assets/Help/zh_CN deltachat-ios/Assets/Help/zh-Hant
cp scripts/local-help-image-replacements/*.png deltachat-ios/Assets/Help
