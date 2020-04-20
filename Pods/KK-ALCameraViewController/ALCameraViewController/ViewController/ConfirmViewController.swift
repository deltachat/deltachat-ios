//
//  ALConfirmViewController.swift
//  ALCameraViewController
//
//  Created by Alex Littlejohn on 2015/06/30.
//  Copyright (c) 2015 zero. All rights reserved.
//
//
//  Modified by Kevin Kieffer on 2019/08/06.  Changes as follows:  significantly updated the operation of this
//  class because as far as I could determine the subviews were not arranging themselves properly when the
//  device was rotated. Simplified this class by removing the centeringView and scrollView insets, and simply centering the
//  scrollView in the overall view, setting the scrollView content size = imageView frame size, and centering the cropOverlay
//  over the scrollView whenever the view finished laying out its subviews.
//
//  Furthermore minimum scrollView zoom size was set based on the crop rectangle, but the initial view was set to fully
//  fit the image on the screen.
//
//  A new aspectRatio constraint was created and all constraints were removed from the cropOverlay view in the .xib file.
//  The centeringView was also removed from the .xib file and the Confirm and Cancel buttons were moved closer to the edge.
//
//  A center touch point is set on the CropOverlay if the CropParameters say its movable
//
//  Lastly, the image cropping worked differently if the crop rectangle was out of the image bounds, depending on whether
//  the image came from a PHAsset or a UIImage. In the former, the crop maintained the aspect ratio of the crop rectangle
//  (possibly distorting the image), but in the latter, it truncated the crop rectangle to the bounds of the image, changing
//  the aspect ratio.  Since maintaining the aspect ratio is preferred, a change to the UIImage extension was made to rescale the
//  cropped image back to the aspect ratio, which also possibly distorts the image but preserves the aspect ratio.




import UIKit
import Photos

public class ConfirmViewController: UIViewController, UIScrollViewDelegate {
	
    var CROP_PADDING : CGFloat {
        switch UIDevice.current.userInterfaceIdiom {
        case .pad:
            return CGFloat(120)
        default:
            return CGFloat(30)
        }
    }
    
	let imageView = UIImageView()
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var cropOverlay: CropOverlay!
    @IBOutlet weak var confirmButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var rotateButton: UIButton!
    
    
    
    var croppingParameters: CroppingParameters {
        didSet {
            cropOverlay.showsCenterPoint = croppingParameters.allowMoving
            cropOverlay.isResizable = croppingParameters.allowResizing
            cropOverlay.isMovable = croppingParameters.allowMoving
            cropOverlay.minimumSize = croppingParameters.minimumSize
            cropOverlay.showsButtons = croppingParameters.allowResizing
        }
    }

	public var onComplete: CameraViewCompletion?

	let asset: PHAsset?
	let image: UIImage?
	
    var didInitialAdjustCropOverlay = false
    var didInitialCenterCropOverlay = false

	public init(image: UIImage, croppingParameters: CroppingParameters) {
		self.croppingParameters = croppingParameters
		self.asset = nil
		self.image = image
		super.init(nibName: "ConfirmViewController", bundle: CameraGlobals.shared.bundle)
	}
	
	public init(asset: PHAsset, croppingParameters: CroppingParameters) {
		self.croppingParameters = croppingParameters
		self.asset = asset
		self.image = nil
		super.init(nibName: "ConfirmViewController", bundle: CameraGlobals.shared.bundle)
	}
	
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
	}
	
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
	public override var prefersStatusBarHidden: Bool {
		return true
	}
	
	public override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
		return UIStatusBarAnimation.slide
	}
	
	public override func viewDidLoad() {
		super.viewDidLoad()

		view.backgroundColor = UIColor.black
		
		scrollView.addSubview(imageView)
		scrollView.delegate = self
		scrollView.maximumZoomScale = croppingParameters.maximumZoom
		
        cropOverlay.showsCenterPoint = croppingParameters.allowMoving
        cropOverlay.isHidden = true
        cropOverlay.isResizable = croppingParameters.allowResizing
        cropOverlay.isMovable = croppingParameters.allowMoving
        cropOverlay.minimumSize = croppingParameters.minimumSize
        cropOverlay.showsButtons = croppingParameters.allowResizing

        if !croppingParameters.allowRotate {
            rotateButton.isHidden = true
        }
        
		let spinner = showSpinner()
		
		disable()
		
		if let asset = asset {  //load full resolution image size
			_ = SingleImageFetcher()
				.setAsset(asset)
				.onSuccess { [weak self] image in
					self?.configureWithImage(image)
					self?.hideSpinner(spinner)
					self?.enable()
				}
				.onFailure { [weak self] error in
					self?.hideSpinner(spinner)
				}
				.fetch()
		} else if let image = image {
			configureWithImage(image)
			hideSpinner(spinner)
			enable()
		}
        
        NotificationCenter.default.addObserver(self, selector: #selector(orientationChanged), name:  Notification.Name("UIDeviceOrientationDidChangeNotification"), object: nil)

	}
    
    @objc func orientationChanged() {
        centerCropFrame()
    }
	
    public override func viewWillLayoutSubviews() {
        
        if !didInitialAdjustCropOverlay || !cropOverlay.isResizable {
            adjustCropOverlay()  //keep it centered and constrainted on orientation changes
            didInitialAdjustCropOverlay = true
        }
        
    }
	
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        
        let (minscale, initscale) = calculateMinimumAndInitialScale()
        
        scrollView.contentSize = imageView.frame.size
        scrollView.minimumZoomScale = minscale
        scrollView.zoomScale = initscale

        self.centerScrollViewContents()
        
        if !cropOverlay.isResizable || !didInitialCenterCropOverlay {
            self.centerCropFrame()
            didInitialCenterCropOverlay = true
        }
        
    }
    
    private func adjustCropOverlay() {
        switch UIDevice.current.orientation {
        case .landscapeLeft, .landscapeRight:
            cropOverlay.frame.size.height = view.frame.height - CROP_PADDING  //height is constrained in landscale
            cropOverlay.frame.size.width = cropOverlay.frame.size.height / croppingParameters.aspectRatioHeightToWidth
        default:
             cropOverlay.frame.size.width = view.frame.width - CROP_PADDING //width is constrained in portrait
             cropOverlay.frame.size.height = cropOverlay.frame.size.width * croppingParameters.aspectRatioHeightToWidth
        }
    }
	
	private func configureWithImage(_ image: UIImage) {
		cropOverlay.isHidden = !croppingParameters.isEnabled
		
		buttonActions()
		
		imageView.image = image
		imageView.sizeToFit()
		view.setNeedsLayout()
	}
	
    
    //Returns a tuple containing the minimum scale and the desired initial scale of the scroll view
	private func calculateMinimumAndInitialScale() -> (CGFloat, CGFloat) {
        guard let image = imageView.image else {
            return (1,1)
        }
    
        //The initial scale will fit the entire image on the screen in either orientation
        let size = view.bounds
        let scaleWidth = size.width / image.size.width
        let scaleHeight = size.height / image.size.height
    
        let minSizeWithoutCrop = min(scaleWidth, scaleHeight)
    
    
        //If cropping enabled, the minimum scale fits the image into the crop rectangle, otherwise
        //its the same as in the initial scale
		if croppingParameters.isEnabled {
            
            let cropSize = cropOverlay.frame.size
            let cropScaleWidth = (cropSize.width - CROP_PADDING) / image.size.width
            let cropScaleHeight = (cropSize.height - CROP_PADDING) / image.size.height
            
            let minSizeWithCrop = min(cropScaleWidth, cropScaleHeight)
    
            return (minSizeWithCrop, minSizeWithoutCrop)
		}
        else {
            return (minSizeWithoutCrop, minSizeWithoutCrop)
        }
		
	}
	
	private func calculateScrollViewInsets(_ frame: CGRect) -> UIEdgeInsets {
		let bottom = view.frame.height - (frame.origin.y + frame.height)
		let right = view.frame.width - (frame.origin.x + frame.width)
		let insets = UIEdgeInsets(top: frame.origin.y, left: frame.origin.x, bottom: bottom, right: right)
		return insets
	}
	
	private func centerImageViewOnRotate() {
		if croppingParameters.isEnabled {
			let size = cropOverlay.frame.size
			let scrollInsets = scrollView.contentInset
			let imageSize = imageView.frame.size
			var contentOffset = CGPoint(x: -scrollInsets.left, y: -scrollInsets.top)
			contentOffset.x -= (size.width - imageSize.width) / 2
			contentOffset.y -= (size.height - imageSize.height) / 2
			scrollView.contentOffset = contentOffset
		}
	}
	
    private func centerCropFrame() {
        let size = scrollView.frame.size
        let cropSize = cropOverlay.frame.size
        var origin = CGPoint.zero
        
        if cropSize.width < size.width {
            origin.x = (size.width - cropSize.width) / 2
        }
        
        if cropSize.height < size.height {
            origin.y = (size.height - cropSize.height) / 2
        }
        
        cropOverlay.frame.origin = origin
    }
    
	private func centerScrollViewContents() {
		let size = scrollView.frame.size
		let imageSize = imageView.frame.size
		var imageOrigin = CGPoint.zero
		
		if imageSize.width < size.width {
			imageOrigin.x = (size.width - imageSize.width) / 2
		}
		
		if imageSize.height < size.height {
			imageOrigin.y = (size.height - imageSize.height) / 2
		}
		
		imageView.frame.origin = imageOrigin
	}
	
	private func buttonActions() {
		confirmButton.action = { [weak self] in self?.confirmPhoto() }
		cancelButton.action = { [weak self] in self?.cancel() }
        rotateButton.action = { [weak self] in self?.rotateRight() }
	}
    
    internal func rotateRight() {
        if let rotatedImage = imageView.image?.rotate() {
            configureWithImage(rotatedImage)
            centerScrollViewContents()
        }
    }
	
	internal func cancel() {
        cropOverlay.removeFromSuperview()  //remove overlay while processing
		onComplete?(nil, nil)
	}
	
	internal func confirmPhoto() {
		
		guard let image = imageView.image else {
			return
		}
		
		disable()
		
		imageView.isHidden = true
		
		let spinner = showSpinner()
		        
        if croppingParameters.isEnabled {
            let cropRect = makeProportionalCropRect()
            let resizedCropRect = CGRect(x: (image.size.width) * cropRect.origin.x,
                                 y: (image.size.height) * cropRect.origin.y,
                                 width: (image.size.width * cropRect.width),
                                 height: (image.size.height * cropRect.height))
            
            DispatchQueue.global(qos: .userInitiated).async {
                let croppedImage = image.crop(rect: resizedCropRect)  //This can take long time and block UI
                DispatchQueue.main.async {
                    self.onComplete?(croppedImage, self.asset)
                    self.hideSpinner(spinner)
                }
            }
            
        }
        else {
            onComplete?(image, self.asset)
            hideSpinner(spinner)
        }
		
        cropOverlay.removeFromSuperview()  //remove overlay while processing
	}
	
	public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
		return imageView
	}
	
	public func scrollViewDidZoom(_ scrollView: UIScrollView) {
		centerScrollViewContents()
	}
    
    
    override public func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        view.setNeedsLayout()
    }
	
	func showSpinner() -> UIActivityIndicatorView {
		let spinner = UIActivityIndicatorView()
        spinner.style = .white
		spinner.center = view.center
		spinner.startAnimating()
		
		view.addSubview(spinner)
        view.bringSubviewToFront(spinner)
		
		return spinner
	}
	
	func hideSpinner(_ spinner: UIActivityIndicatorView) {
		spinner.stopAnimating()
		spinner.removeFromSuperview()
	}
	
	func disable() {
		confirmButton.isEnabled = false
        cancelButton.isEnabled = false
	}
	
	func enable() {
		confirmButton.isEnabled = true
        cancelButton.isEnabled = true
	}
	
	func showNoImageScreen(_ error: NSError) {
		let permissionsView = PermissionsView(frame: view.bounds)
		
		let desc = localizedString("error.cant-fetch-photo.description")
		
		permissionsView.configureInView(view, title: error.localizedDescription, description: desc, completion: { [weak self] in self?.cancel() })
	}
	
	private func makeProportionalCropRect() -> CGRect {
		var cropRect = CGRect(x: cropOverlay.frame.origin.x + cropOverlay.outterGap,
		                      y: cropOverlay.frame.origin.y + cropOverlay.outterGap,
		                      width: cropOverlay.frame.size.width - 2 * cropOverlay.outterGap,
		                      height: cropOverlay.frame.size.height - 2 * cropOverlay.outterGap)
        
        cropRect.origin.x += scrollView.contentOffset.x - imageView.frame.origin.x
        cropRect.origin.y += scrollView.contentOffset.y - imageView.frame.origin.y

		let normalizedX = cropRect.origin.x / imageView.frame.width
		let normalizedY = cropRect.origin.y / imageView.frame.height

        let extraWidth = CGFloat(0) //fabs(cropRect.origin.x)
        let extraHeight = CGFloat(0) //fabs(cropRect.origin.y)

		let normalizedWidth = (cropRect.width + extraWidth) / imageView.frame.width
		let normalizedHeight = (cropRect.height + extraHeight) / imageView.frame.height
		
		return CGRect(x: normalizedX, y: normalizedY, width: normalizedWidth, height: normalizedHeight)
	}
	
}

extension UIImage {
    
	func crop(rect: CGRect) -> UIImage {

		var rectTransform: CGAffineTransform
		switch imageOrientation {
		case .left:
			rectTransform = CGAffineTransform(rotationAngle: radians(90)).translatedBy(x: 0, y: -size.height)
		case .right:
			rectTransform = CGAffineTransform(rotationAngle: radians(-90)).translatedBy(x: -size.width, y: 0)
		case .down:
			rectTransform = CGAffineTransform(rotationAngle: radians(-180)).translatedBy(x: -size.width, y: -size.height)
		default:
			rectTransform = CGAffineTransform.identity
		}
		
		rectTransform = rectTransform.scaledBy(x: scale, y: scale)
		
        let cropAspect = rect.height / rect.width
        
        if let cropped = cgImage?.cropping(to: rect.applying(rectTransform)) {
            
			let cropImage = UIImage(cgImage: cropped, scale: scale, orientation: imageOrientation).fixOrientation()
            
            
            //Rescale the cropped portion to maintain the crop aspect ratio
            let currentAspect = cropImage.size.height / cropImage.size.width
                        
            return cropImage.scaledBy(size: CGSize(width: cropImage.size.width, height: cropImage.size.height * cropAspect / currentAspect)) ?? self
            
           
        }
		
		return self
	}
	
	func fixOrientation() -> UIImage {
		if imageOrientation == .up {
			return self
		}
		
		UIGraphicsBeginImageContextWithOptions(size, false, scale)
		draw(in: CGRect(origin: .zero, size: size))
		let normalizedImage: UIImage = UIGraphicsGetImageFromCurrentImageContext() ?? self
		UIGraphicsEndImageContext()
		
		return normalizedImage
	}
    
    func scaledBy(size: CGSize) -> UIImage? {
        let hasAlpha = false
        let scale: CGFloat = 0.0 // Automatically use scale factor of main screen
        
        UIGraphicsBeginImageContextWithOptions(size, !hasAlpha, scale)
        self.draw(in: CGRect(origin: CGPoint(x: 0, y: 0), size: size))
        
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return scaledImage
    }
    
    //Rotate by 90 degrees
    func rotate() -> UIImage? {
        
        let radians = Float.pi/2
        
        var newSize = CGRect(origin: CGPoint.zero, size: CGSize(width: self.size.width, height: self.size.height)).applying(CGAffineTransform(rotationAngle: CGFloat(radians))).size
        
        // Trim off the extremely small float value to prevent core graphics from rounding it up
        newSize.width = floor(newSize.width)
        newSize.height = floor(newSize.height)

        UIGraphicsBeginImageContextWithOptions(newSize, false, self.scale)
        let context = UIGraphicsGetCurrentContext()!
        
        // Move origin to middle
        context.translateBy(x: newSize.width/2, y: newSize.height/2)
        // Rotate around middle
        context.rotate(by: CGFloat(radians))
        // Draw the image at its center
        self.draw(in: CGRect(x: -self.size.width/2, y: -self.size.height/2, width: self.size.width, height: self.size.height))

        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage
    }
}
