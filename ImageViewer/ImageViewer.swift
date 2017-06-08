//
//  ImageViewer.swift
//  ImageViewer
//
//  Created by Andrés Pizá Bückmann on 04/06/2017.
//  Copyright © 2017 Andrés Pizá Bückmann. All rights reserved.
//

import UIKit

class ImageViewer: UIViewController {
    fileprivate let originalImageView: UIImageView
    fileprivate let presentingVC: UIViewController
    fileprivate var imageView = UIImageView()
    fileprivate var scrollView = UIScrollView()
    
    // Dissmiss with flick vars
    fileprivate var flickedToDismiss = false
    fileprivate var isDraggingImage = false
    fileprivate var imageDragStartingPoint: CGPoint!
    fileprivate var imageDragOffsetFromActualTranslation: UIOffset!
    fileprivate var imageDragOffsetFromImageCenter: UIOffset!
    fileprivate var attachmentBehavior: UIAttachmentBehavior?
    fileprivate var animator = UIDynamicAnimator()
    
    static func showImage(imageView: UIImageView, presentingVC: UIViewController) {
        let imageViewer = ImageViewer(imageView: imageView, presentingVC: presentingVC)
        imageViewer.presentingVC.present(imageViewer, animated: false, completion: nil)
    }
    
    init(imageView: UIImageView, presentingVC: UIViewController) {
        self.originalImageView = imageView
        self.presentingVC = presentingVC
        super.init(nibName: nil, bundle: nil)
        
        configureView()
        configureGestureRecognizers()
        
        self.modalPresentationStyle = .overCurrentContext
    }
    
    fileprivate func configureGestureRecognizers() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(ImageViewer.tapImage(_:)))
        scrollView.addGestureRecognizer(tap)
        
        let swipeDismiss = UIPanGestureRecognizer(target: self, action: #selector(ImageViewer.scrollViewDidSwipeToDismiss(_:)))
        swipeDismiss.delegate = self
        self.view.addGestureRecognizer(swipeDismiss)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.view.addSubview(scrollView)
        displayImage()
    }
    
    fileprivate func displayImage() {
        guard let image = originalImageView.image else { return }
        
        imageView.image = image
        imageView.frame = originalImageView.convert(originalImageView.bounds, to: self.view)
        
        UIView.animate(withDuration: 0.2, animations: {
            let imageSize = image.size
            let imageOrigin = CGPoint(x: self.view.frame.size.width/2 - imageSize.width/2, y: self.view.frame.size.height/2 - imageSize.height/2)
            self.imageView.frame = CGRect(x: imageOrigin.x, y: imageOrigin.y, width: imageSize.width, height: imageSize.height)
        })
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    fileprivate func configureView() {
        // ImageViewer's view
        self.view = UIView(frame: UIScreen.main.bounds)
        
        // Blur background
        if !UIAccessibilityIsReduceTransparencyEnabled() {
            self.view.backgroundColor = UIColor.clear
            
            let blurEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .light))
            blurEffectView.contentView.isUserInteractionEnabled = true
            blurEffectView.frame = self.view.bounds
            blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            
            self.view.addSubview(blurEffectView)
        } else {
            self.view.backgroundColor = UIColor.black
        }
        
        scrollView.frame = self.view.bounds
        scrollView.maximumZoomScale = 10
        scrollView.minimumZoomScale = 1
        scrollView.delegate = self
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // Image view
        imageView.frame = self.view.bounds
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        scrollView.addSubview(imageView)
        
        animator = UIDynamicAnimator(referenceView: scrollView)
    }
    
    func tapImage(_ sender: UITapGestureRecognizer) {
        UIView.animate(withDuration: 0.2, animations: {
            self.imageView.frame = self.originalImageView.frame
        }, completion: { finished in self.dismiss(animated: false) })
    }
}

extension ImageViewer: UIScrollViewDelegate, UIGestureRecognizerDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return self.imageView
    }
    
    // When zooming, center the image
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        let horizontalOffset = (scrollView.bounds.size.width > scrollView.contentSize.width) ? ((scrollView.bounds.size.width - scrollView.contentSize.width) * 0.5): 0.0
        let verticalOffset   = (scrollView.bounds.size.height > scrollView.contentSize.height) ? ((scrollView.bounds.size.height - scrollView.contentSize.height) * 0.5): 0.0
        
        imageView.center = CGPoint(x: scrollView.contentSize.width * 0.5 + horizontalOffset, y: scrollView.contentSize.height * 0.5 + verticalOffset)
    }
    
    func scrollViewDidSwipeToDismiss(_ gesture: UIPanGestureRecognizer) {
        // Only dismiss when not zoomed in
        guard scrollView.zoomScale == scrollView.minimumZoomScale else { return }
        
        let translation = gesture.translation(in: gesture.view!)
        let locationInView = gesture.location(in: gesture.view)
        let velocity = gesture.velocity(in: gesture.view)
        let vectorDistance = sqrt(pow(velocity.x, 2) + pow(velocity.y, 2))
        
        if gesture.state == .began {
            isDraggingImage = imageView.frame.contains(locationInView)
            if isDraggingImage {
                startImageDragging(locationInView, translationOffset: .zero)
            }
        } else if gesture.state == .changed {
            if isDraggingImage {
                var newAnchor = imageDragStartingPoint
                newAnchor?.x += translation.x + imageDragOffsetFromActualTranslation.horizontal
                newAnchor?.y += translation.y + imageDragOffsetFromActualTranslation.vertical
                attachmentBehavior?.anchorPoint = newAnchor!
            } else {
                print("never enter here")
                isDraggingImage = imageView.frame.contains(locationInView)
                if isDraggingImage {
                    let translationOffset = UIOffset(horizontal: -1 * translation.x, vertical: -1 * translation.y)
                    startImageDragging(locationInView, translationOffset: translationOffset)
                }
            }
        } else {
            if vectorDistance > 800 {
                if isDraggingImage {
                    dismissWithFlick(velocity)
                } else {
//                    dismiss()
                }
            } else {
                cancelCurrentImageDrag(true)
            }
        }
    }
    
    fileprivate func dismissWithFlick(_ velocity: CGPoint) {
        flickedToDismiss = true
        
        let push = UIPushBehavior(items: [imageView], mode: .instantaneous)
        push.pushDirection = CGVector(dx: velocity.x * 0.1, dy: velocity.y * 0.1)
        push.setTargetOffsetFromCenter(imageDragOffsetFromImageCenter, for: imageView)
        push.action = pushAction
        animator.removeBehavior(attachmentBehavior!)
        animator.addBehavior(push)
    }
    
    fileprivate func pushAction() {
        if isImageViewOffscreen() {
            animator.removeAllBehaviors()
            attachmentBehavior = nil
            imageView.removeFromSuperview()
            dismiss()
        }
    }
    
    fileprivate func isImageViewOffscreen() -> Bool {
        let visibleRect = scrollView.convert(contentView.bounds, from: contentView)
        return animator.items(in: visibleRect).count == 0
    }
    
    fileprivate func cancelCurrentImageDrag(_ animated: Bool) {
        animator.removeAllBehaviors()
        attachmentBehavior = nil
        isDraggingImage = false
        
        if !animated {
            imageView.transform = .identity
            imageView.center = CGPoint(x: scrollView.contentSize.width / 2, y: scrollView.contentSize.height / 2)
        } else {
            UIView.animate(withDuration: 0.7,
                           delay: 0,
                           usingSpringWithDamping: 0.7,
                           initialSpringVelocity: 0,
                           options: [.allowUserInteraction, .beginFromCurrentState],
                           animations: { [unowned self] in
                            guard !self.isDraggingImage else { return }
                            
                            self.imageView.transform = CGAffineTransform.identity
                            if !self.scrollView.isDragging && !self.scrollView.isDecelerating {
                                self.imageView.center = CGPoint(x: self.scrollView.contentSize.width / 2,
                                                                y: self.scrollView.contentSize.height / 2)
//                                self.updateScrollViewAndImageViewForCurrentMetrics()
                            }
                }, completion: nil)
        }
    }
    
//    func updateScrollViewAndImageViewForCurrentMetrics() {
//        scrollView.frame = scrollView.contentView.bounds
//        if let image = imageView.image {
//            imageView.frame = resizedFrameForSize(image.size)
//        }
//        scrollView.contentSize = imageView.frame.size
//        scrollView.contentInset = contentInsetForScrollView(atScale: scrollView.zoomScale)
//    }
    
//    fileprivate func resizedFrameForSize(_ imageSize: CGSize) -> CGRect {
//        var frame = scrollView.contentView.bounds
//        let screenWidth = frame.width * scrollView.zoomScale
//        let screenHeight = frame.height * scrollView.zoomScale
//        var targetWidth = screenWidth
//        var targetHeight = screenHeight
//        let nativeWidth = max(imageSize.width, screenWidth)
//        let nativeHeight = max(imageSize.height, screenHeight)
//        
//        if nativeHeight > nativeWidth {
//            if screenHeight / screenWidth < nativeHeight / nativeWidth {
//                targetWidth = screenHeight / (nativeHeight / nativeWidth)
//            } else {
//                targetHeight = screenWidth / (nativeWidth / nativeHeight)
//            }
//        } else {
//            if screenWidth / screenHeight < nativeWidth / nativeHeight {
//                targetHeight = screenWidth / (nativeWidth / nativeHeight)
//            } else {
//                targetWidth = screenHeight / (nativeHeight / nativeWidth)
//            }
//        }
//        
//        frame.size = CGSize(width: targetWidth, height: targetHeight)
//        frame.origin = .zero
//        return frame
//    }
    
    fileprivate func startImageDragging(_ locationInView: CGPoint, translationOffset: UIOffset) {
        imageDragStartingPoint = locationInView
        imageDragOffsetFromActualTranslation = translationOffset
        
        let anchor = imageDragStartingPoint
        let imageCenter = imageView.center
        let offset = UIOffset(horizontal: locationInView.x - imageCenter.x, vertical: locationInView.y - imageCenter.y)
        imageDragOffsetFromImageCenter = offset
        attachmentBehavior = UIAttachmentBehavior(item: imageView, offsetFromCenter: offset, attachedToAnchor: anchor!)
        animator.addBehavior(attachmentBehavior!)
        
        let modifier = UIDynamicItemBehavior(items: [imageView])
        modifier.angularResistance = angularResistance(view: imageView)
        modifier.density = density(view: imageView)
        animator.addBehavior(modifier)
    }
    
    fileprivate func angularResistance(view: UIView) -> CGFloat {
        let defaultResistance: CGFloat = 4
        return appropriateValue(defaultValue: defaultResistance) * factor(forView: view)
    }
    
    fileprivate func density(view: UIView) -> CGFloat {
        let defaultDensity: CGFloat = 0.5
        return appropriateValue(defaultValue: defaultDensity) * factor(forView: view)
    }
    
    fileprivate func appropriateValue(defaultValue: CGFloat) -> CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        // Default value that works well for the screenSize adjusted for the actual size of the device
        return defaultValue * ((320 * 480) / (screenWidth * screenHeight))
    }
    
    fileprivate func factor(forView view: UIView) -> CGFloat {
        let actualArea = contentView.bounds.height * view.bounds.height
        let referenceArea = contentView.bounds.height * contentView.bounds.width
        return referenceArea / actualArea
    }
}
