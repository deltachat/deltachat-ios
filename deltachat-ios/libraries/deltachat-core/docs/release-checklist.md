
# release new core version

1. deltachat-core: bump version, check CHANGELOG.md, commit
2. $ VERSION=1.2.3
3. $ git tag -s -m "Release v${VERSION}" v${VERSION} # create signed tag
4. $ git tag -v v${VERSION} # verify tag signature
5. $ git push origin master
6. $ git push --tags origin


# create the github release with signed binaries

1. "draft a new release" with v${VERSION} on github.com
2. publish release
3. download zip and tar.gz files
4. verify content
5. sign content (to get the key overview, use gpg --list-secret-keys)  
   $ gpg -a --detach-sign -u FINGERPRINT deltachat-core-${VERSION}.zip  
   $ gpg -a --detach-sign -u FINGERPRINT deltachat-core-${VERSION}.tar.gz
6. upload created signatures to github,
   rename to v${VERSION}.zip.asc and v${VERSION}.tar.gz.asc

