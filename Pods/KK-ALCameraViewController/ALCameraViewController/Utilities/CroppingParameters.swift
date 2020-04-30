//
//  CroppingParameters.swift
//  ALCameraViewController
//
//  Created by Guillaume Bellut on 02/09/2017.
//  Copyright © 2017 zero. All rights reserved.
//
//  Modified by Kevin Kieffer on 2019/08/06.  Changes as follows:
//  Adding an aspectRatio for the cropping rectangle. Default is 1 (a square)


import UIKit

public struct CroppingParameters {

    /// Enable the cropping feature.
    /// Default value is set to false.
    let isEnabled: Bool
    
    /// Enable the overlay on the camera feature
    /// Default is set to true
    let cameraOverlay : Bool

    /// Allow the cropping area to be resized by the user.
    /// Default value is set to true.
    let allowResizing: Bool

    /// Allow the cropping area to be moved by the user.
    /// Default value is set to false.
    let allowMoving: Bool
    
    
    /// Allow rotating 90 degrees in the confirm view
    /// Default value is set to true
    let allowRotate: Bool
    
    /// Aspect ratio of the crop
    let aspectRatioHeightToWidth : CGFloat

    /// Prevent the user to resize the cropping area below a minimum size.
    /// Default value is (60, 60). Below this value, corner buttons will overlap.
    let minimumSize: CGSize
    
    /// The maximum scale factor the user can zoom in, default of 1
    let maximumZoom : CGFloat

    public init(isEnabled: Bool = false,
                allowResizing: Bool = true,
                allowMoving: Bool = true,
                allowRotate: Bool = true,
         minimumSize: CGSize = CGSize(width: 60, height: 60),
         aspectRatioHeightToWidth: CGFloat = 1.0,
         maximumZoom: CGFloat = 1.0,
         cameraOverlay : Bool = true) {

        self.isEnabled = isEnabled
        self.allowResizing = allowResizing
        self.allowMoving = allowMoving
        self.allowRotate = allowRotate
        self.minimumSize = minimumSize
        self.aspectRatioHeightToWidth = aspectRatioHeightToWidth
        self.maximumZoom = maximumZoom
        self.cameraOverlay = cameraOverlay
    }
}
