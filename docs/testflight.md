# release on testflight

1. update core rust submodule, if needed:
   ```
   $ cd deltachat-ios/libraries/deltachat-core-rust
   $ cargo update          # as needed
   $ git checkout master   # or whatever should be used
   $ git pull
   $ cd ../../..
   $ git commit -am "update core submodule"
   ```
2. in Xcode:
   - adapt version as needed ("View/Navigator/Project Navigator/deltachat-ios",
     target "deltachat-ios", then "General/Version")
   - if the version was changed, increase the build number in the same dialog
   - select "Generic iOS Device" in the toolbar
   - menu "Product/Archive" ... coffee ...
     (codesign may ask for a password, this _may_ be empty and "Enter" will do)
   - on success, a dialog with all releases on the machine is shown;
     click on the most recent and select "Distribute", then "iOS App Store",
	 then "Upload", leave default options, in the summary, click "Upload" again

3. on https://appstoreconnect.apple.com :
   - open "My Apps/Delta Chat/TestFlight/" 

