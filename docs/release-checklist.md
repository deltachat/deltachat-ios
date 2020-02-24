# Release checklist

on the command-line:

1. update core rust submodule, if needed:
   $ ./tools/update-core.sh
   depending on how much you trust in rust, you might want to do a
   ./tools/clean-core.sh before building

2. update translations:
   $ ./tools/tx-pull-translations.sh

3. update local help:
   $ cd ../deltachat-pages; ./tools/create-local-help.py; cd ../deltachat-ios

4. update CHANGELOG.md
   (the core-changelog at
   https://github.com/deltachat/deltachat-core-rust/blob/master/CHANGELOG.md
   and the "N commits to master since last release" on
   https://github.com/deltachat/deltachat-ios/releases gives some good hints)

in Xcode:

5. a) adapt version ("View/Navigator/Project Navigator/deltachat-ios",
      target "deltachat-ios", then "General/Version")
   b) increase the build number in the same dialog

6. a) select "Generic iOS Device" in the toolbar
   b) select menu "Product/Archive"
      (codesign may ask for a password, this _may_ be empty and "Enter" will do)
   c) on success, a dialog with all releases on the machine is shown;
      select the most recent, then "Distribute/App Store Connect/Upload"
      leave default options (strip symbols: yes, upload symbols: yes),
      in the summary, click "Upload" again ... coffees ...

on https://appstoreconnect.apple.com :

7. for a **Testflight release**, open "My Apps/Delta Chat/TestFlight/iOS"
   a) fill out compliance info, status should be "Ready to Submit" then
   b) select "open-testing-group" on the left, then "Builds" tab
   c) click "+" and select the version made "Ready to submit" above
   d) make sure the credentials shown on the next page are working
      (the credentials are needed by apple for review)

   OR

8. for a **Reguar release**, open "My Apps/Delta Chat/+Version or Platform"
   and follow the dialogs

finally, back on command line:

9. commit changes from 1.-4.
   and on Github: "Draft a new release" with a version in the form `v1.2.3`
