# this script generates the c-api html-help-pages
# from the c-core-source using `doxygen`

UPLOADDIR="../../api"

doxygen
mkdir -p ${UPLOADDIR}/docs/
cp -r html/* ${UPLOADDIR}/docs/
read -p "if not errors are printed above, press ENTER to commit and push the changes"

pushd . > /dev/null

cd ${UPLOADDIR}
git add docs/
git commit -am "update docs"
git push

popd > /dev/null



