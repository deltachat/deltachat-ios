# release on testflight

1. update core rust submodule, if needed:
   $ ./tools/update-core.sh

2. in Xcode:
   - adapt version ("View/Navigator/Project Navigator/deltachat-ios",
     target "deltachat-ios", then "General/Version")
   - increase the build number in the same dialog
   - select "Generic iOS Device" in the toolbar
   - menu "Product/Archive" ... coffee ...
     (codesign may ask for a password, this _may_ be empty and "Enter" will do)
   - on success, a dialog with all releases on the machine is shown;
     click on the most recent and select "Distribute", then "iOS App Store",
	 then "Upload", leave default options, in the summary, click "Upload" again

3. on https://appstoreconnect.apple.com :
   - open "My Apps/Delta Chat/TestFlight/iOS"
   - fill out compliance info, status should be "Ready to Submit" then
   - select "open-testing-group" on the left, then "Builds" tab
   - click "+" and select the version made "Ready to submit" above
   - make sure the credentials shown on the next page are working
     (the credentials are needed by apple for review)

4. - deltachat-ios on Github: "Draft a new release"
     with a version in the form `v1.2.3`
