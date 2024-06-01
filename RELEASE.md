# Release checklist

on the command-line:

1. update core:
   ```
   ./scripts/update-core.sh               # shows used branch
   ./scripts/update-core.sh BRANCH_OR_TAG # update to tag or latest commit of branch
   ./scripts/clean-core.sh                # helps on weird issues, do also "Build / Clean"
   ```

2. update translations:
   $ ./scripts/tx-pull-translations.sh

3. update local help:
   $ ./scripts/create-local-help.sh

4. a) update CHANGELOG.md
      from https://github.com/deltachat/deltachat-core-rust/blob/main/CHANGELOG.md
      and https://github.com/deltachat/deltachat-ios/pulls?q=is%3Apr+is%3Aclosed+sort%3Aupdated-desc
   b) add used core version to CHANGELOG.md
   c) add a device message to ChatListController::viewDidLoad()
      or remove the old one

in Xcode:

5. a) adapt version ("View/Navigators/Project/deltachat-ios",
      target "deltachat-ios", then "General/Version")
   b) increase the build number in the same dialog
   c) navigate to "DcShare / Build Settings / Versioning"
      and adapt "Marketing Version" and "Current Project Version"
   d) same for "DcNotificationService"

6. a) select "Any iOS Device (arm64)" in the toolbar
   b) select menu "Product/Archive"
      (codesign may ask for a password, this _may_ be empty and "Enter" will do)
   c) on success, a dialog with all releases on the machine is shown;
      select the most recent,
      then "Distribute App / App Store Connect", use defaults, "Distribute"

on https://appstoreconnect.apple.com :

7. for a **Testflight release**, open "My Apps / Delta Chat / TestFlight / iOS"
   a) status becomes "Ready to Submit" automatically after some minutes
   b) select "open-testing-group" on the left, scroll down to "Builds" section
   c) click "+" and select the version made "Ready to submit" above
   d) make sure the credentials shown on the next page are working
      (the credentials are needed by apple for review)

   OR

8. for a **Regular release**, open "My Apps/Delta Chat iOS/iOS App+ (first item)"
   a) enter the version number (without leading "v")
   b) fill out "what's new", use CHANGELOG.md as a template, add the line:
      "These features will roll out over the coming days. Thanks for using Delta Chat!"
   c) select a build
   d) make sure, the credentials for the apple-review-team are working
   e) select "Release update over 7-day period using phased release"
   f) click on "Save" and then "Add for Review"
   g) on the "Confirm Submission" page, another time "Submit to App Review"
   the overview must read for the new version "Waiting for Review" afterwards

   wrt ads: we do not use ads, answer "No".
   final state should be "Waiting for Review" - if it is only "Ready for Review",
   watch out for some additional alerts.

in both cases, make sure, the provided test-email-address is working.
finally, back on command line:

9. commit changes from 1.-5. add add a tag:
   $ git tag v1.2.3; git push --tags
