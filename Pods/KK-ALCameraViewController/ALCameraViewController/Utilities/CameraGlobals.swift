//
//  CameraGlobals.swift
//  ALCameraViewController
//
//  Created by Alex Littlejohn on 2016/02/16.
//  Copyright © 2016 zero. All rights reserved.
//
//  Modified by Kevin Kieffer on 2019/08/06.  Changes as follows:
//  Adding adjustable number of columns for library view, based on .ipad or smaller device



import UIKit
import AVFoundation

internal let itemSpacing: CGFloat = 1
internal let scale = UIScreen.main.scale

public class CameraGlobals {
    public static let shared = CameraGlobals()
    
    public var bundle = Bundle(for: CameraViewController.self)
    public var stringsTable = "CameraView"
    public var defaultCameraPosition = AVCaptureDevice.Position.back
    
    public static let MAX_COLUMNS : Int = {
        switch UIDevice.current.userInterfaceIdiom {
        case .pad:
            return 20
        default:
            return 10
        }
    }()
    
    public static let MIN_COLUMNS = 2
    
    public static let DEFAULT_COLUMNS : Int = {
        switch UIDevice.current.userInterfaceIdiom {
        case .pad:
            return 8
        default:
            return 4
        }
    }()
    
      
    public func photoLibraryThumbnailSize(withColumns columns : Int) -> CGSize {
        
        let cols = CGFloat(columns)
        let thumbnailDimension = (UIScreen.main.bounds.width - ((cols * itemSpacing) - itemSpacing))/cols
        return CGSize(width: thumbnailDimension, height: thumbnailDimension)
            
        
    }
    
}
