#!/bin/bash

# This script pulls android translations from transifex and converts them to apple strings files. 
# Credits to Daniel Cohen Gindi.



cd scripts

TMP_ANDROID_TRANSLATIONS=tmpAndroidTranslations

if [[ -z `which tx` ]] 
then
    echo "ERROR: You need to have tx installed. Exiting."
    exit 
fi

if [[ -d $TMP_ANDROID_TRANSLATIONS ]] 
then 
    rm -rf $TMP_ANDROID_TRANSLATIONS
fi

IOS_TRANSLATIONS=( $(find .. -name Localizable.strings) )

mkdir $TMP_ANDROID_TRANSLATIONS
tx pull --source --translations --all --force

for (( i=0; i<${#IOS_TRANSLATIONS[@]}; i++ )) {
    LANG_DIR=`echo ${IOS_TRANSLATIONS[i]} | awk -F '.lproj' '{print $1}' | rev | cut -d '/' -f1 | rev`
    OUTPUT_DIR=`echo ${IOS_TRANSLATIONS[i]} | sed 's/\/Localizable.strings//g'`
    #echo "convertTranslations: $TMP_ANDROID_TRANSLATIONS/$LANG_DIR/strings.xml -> ${IOS_TRANSLATIONS[i]} (${OUTPUT_DIR})"

    if [[ $LANG_DIR == "en" && -f untranslated.xml ]] 
    then
        python3 convert_translations.py $TMP_ANDROID_TRANSLATIONS/$LANG_DIR/strings.xml untranslated.xml ${OUTPUT_DIR} || { break; }
    else 
        python3 convert_translations.py $TMP_ANDROID_TRANSLATIONS/$LANG_DIR/strings.xml ${OUTPUT_DIR} || { break; }
    fi
}

rm -rf $TMP_ANDROID_TRANSLATIONS

cd ..

