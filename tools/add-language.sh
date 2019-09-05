# add a language, must be executed from the repo root

if [ $# -eq 0 ]
then
  echo "Please specify the language to add as the first argument (dk, ru etc.)"
  exit
fi

LANG=$1

mkdir ./deltachat-ios/$LANG.lproj/

cp ./deltachat-ios/en.lproj/Localizable.strings ./deltachat-ios/$LANG.lproj/
cp ./deltachat-ios/en.lproj/Localizable.stringsdict ./deltachat-ios/$LANG.lproj/
cp ./deltachat-ios/en.lproj/Untranslated.stringsdict ./deltachat-ios/$LANG.lproj/

echo "res/values-$LANG/strings.xml added:"
echo "- if needed, language mappings can be added to tools/.tx/config"
echo "- then, call ./tools/tx-pull-translations"
