# ALCameraViewController - Forked and Modified

A camera view controller with custom image picker and image cropping. See below for 
a summary of changes for this fork. For detailed changes see notes in source files.

![cropper](https://cloud.githubusercontent.com/assets/932822/8455697/c627ac44-2006-11e5-82be-7f96e73d9b1f.jpg)


## Usage ##

Usage of this fork remains the same as the original but with more options. See the [original README](https://github.com/AlexLittlejohn/ALCameraViewController/blob/master/README.md) for details.

## CocoaPod ##

Incorporate this fork into your project with CocoaPods. Add this line to your podfile:

`pod 'KK-ALCameraViewController'`

## License
ALCameraViewController is available under the MIT license. See the LICENSE file for more info.  This fork retains the same license.


# Changes in this fork

## Compiling

* Updated to Swift 5
* Updated for compatibility with iOS 13

## Cropping

* Image cropping now uses a rectangle with a specified aspect ratio rather than a square.  
* Added a center point circle in the middle of the crop rectangle that shows a touch point for moving the crop overlay. Previously, the user could move the crop overlay by dragging anywhere in the crop bounds, but this prevents pinch-resizing of the image except at the very edge. The resize corners still work as before.

## Camera

* Cleaned up the constraints for the flash, swap, and library buttons to work properly in both landscape orientations
* Update the overlay constraints when rotating, so the overlay is properly positioned and sized
* If the camera is not available (ie. on simulator), pop up an error rather than crashing
* Hide flash button if the flash is not available (for instance, iPads)

## Library Picker

* Adding a pinch gesture to increase or decrease the number of columns shown, up to a min or max value


## Confirm / Cropping View

* Significant updates to the presentation of the image, scrolling, and cropping to fix inconsistencies especially when switching between portrait and landscape.  See source file for full details.
* Allow zooming in on the image during cropping
* Rotate button to rotate the image 90 degrees clockwise on each press

## Example 

* Added a tap gesture on the displayed image to allow re-cropping the image (illustrates bringing up the crop view directly)
* The example was updated to show a crop aspect ratio of 1.2 


