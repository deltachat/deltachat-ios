
# this script updates the deltachat-core-rust sub-repository from github.
# must be executed from the repo root.
#
# - make sure, the deltachat-ios directory is clean
# - make sure, deltachat-core-rust is committed successfully before calling this script

# check out submodules as present in the repository
git submodule update --init --recursive

# update submodule
cd deltachat-ios/libraries/deltachat-core-rust
git checkout master
git pull
cd ../../..

# commit changes
git add deltachat-ios/libraries/deltachat-core-rust
git commit -m "update deltachat-core-rust submodule"

echo "changes are commited to local repo."
echo "use 'git push' to use them or 'git reset HEAD~1; git submodule update --recursive' to abort on your own risk :)"
