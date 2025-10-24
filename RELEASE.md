# Release checklist

on the command-line, in a PR called "update-core-and-stuff-DATE":

1. update core:
   ```
   ./scripts/update-core.sh               # shows used branch
   ./scripts/update-core.sh BRANCH_OR_TAG # update to tag or latest commit of branch
   ./scripts/clean-core.sh                # helps on weird issues, do also "Build / Clean"
   ```

2. update translations and local help:
   ```
   ./scripts/tx-pull-translations.sh
   ./scripts/create-local-help.sh
   ```

the "update-core-and-stuff-DATE" PR can be merged without review
(as everything was already reviewed in their repos).

then, create a "bump-to-VERSION" PR:

3. update CHANGELOG.md:  
   a) add title `## v1.2.3` or `## v1.2.3 Testflight`, add date as `YYYY-MM`
   b) redact lines from `## Unreleased` there  
   c) add core version to end of changelog entry as `- update to core 1.2.3` or `- using core 1.2.3`  
   c) incorporate <https://github.com/deltachat/deltachat-core-rust/blob/main/CHANGELOG.md>
      and redact too technical terms, so that the end user can understand it

   in case previous entries of the changelog refer to not officially released versions,
   the entries should be summarized.
   this makes it easier for the end user to follow changes by showing major changes atop.

4. on major changes, add a device message to `ChatListViewController::viewDidLoad()`
   or remove the old one.
   do not repeat the CHANGELOG here: write what really is the UX outcome
   in a few lines of easy speak without technical terms.
   often, one can peek at Android here :)

in Xcode:

5. bump "Marketing Version" and "Current Project Version"
   ("View/Navigators/Project/deltachat-ios",
   project "deltachat-ios", then "Build Settings/Versioning")

6. a) select "Any iOS Device (arm64)" in the toolbar
   b) select menu "Product/Archive"
      (codesign may ask for a password, this _may_ be empty and "Enter" will do)
   c) on success, a dialog with all releases on the machine is shown;
      select the most recent,
      then "Distribute App / App Store Connect", use defaults, "Distribute"

   This will already push the version to the **Internal Testflight** group
   with selected, named testers.

on https://appstoreconnect.apple.com :

7. First, always create **Open Testflight**, at "My Apps / Delta Chat / TestFlight / iOS"
   a) status becomes "Ready to Submit" automatically after some minutes
   b) select "open-testing-group" on the left, select "Builds" tab
   c) click "+" and select the version made "Ready to submit" above
   d) make sure the credentials shown on the next page are working
      (the credentials are needed by apple for review)

   OR

8. If the Testflight did not show problems, about a day later,
   for a **Regular release**, open "My Apps/Delta Chat iOS/iOS App+ (first item)"
   a) enter the version number (without leading "v")
   b) fill out "what's new", use CHANGELOG.md as a template, add the line:
      "These features will roll out over the coming days. Thanks for using Delta Chat!"
   c) select a build
   d) make sure, the credentials for the apple-review-team are working
   e) select "Release update over 7-day period using phased release"
   f) click on "Save" and then "Add for Review"
   g) in the "Draft Submission" dialog, hit "Submit for Review" another time

   final state should be "Waiting for Review" - if it is only "Ready for Review",
   watch out for some additional alerts.

back on command line:

9. a) commit changes from 1.-5. add add a tag:
      $ git tag v1.2.3; git push --tags
   b) to give our github followers a nice update,
      create a release with notes insipred by device message and CHANGELOG.

finally, drop a not to the testing channels:

and now: here is iOS VERSION - mind your backups:
- 🍏 https://testflight.apple.com/join/uEMc1NxS (Testflight, should keep your data, App Store release will take some days)
what to test: PLEASE_FILL_OUT
