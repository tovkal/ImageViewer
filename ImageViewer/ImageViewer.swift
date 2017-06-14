//
//  ImageViewer.swift
//  ImageViewer
//
//  Created by Andrés Pizá Bückmann on 04/06/2017.
//  Copyright © 2017 Andrés Pizá Bückmann. All rights reserved.
//

import UIKit

/// Image Viewer
///
/// Displays a given ImageView in full screen, blurring the background.
public final class ImageViewer: UIViewController {
    // MARK: - Properties
    // Views
    fileprivate let originalImageView: UIImageView
    fileprivate let presentingVC: UIViewController
    fileprivate lazy var scrollView = UIScrollView()
    fileprivate lazy var imageView = UIImageView()
    fileprivate var blurEffectView: UIVisualEffectView?
    
    // Flick to dismiss vars
    fileprivate var panGesture: UIPanGestureRecognizer?
    fileprivate lazy var isDraggingImage = false
    fileprivate lazy var initialTouchPoint = CGPoint.zero
    fileprivate lazy var dragOffsetFromTranslation = UIOffset.zero
    fileprivate var attachmentBehavior: UIAttachmentBehavior?
    fileprivate lazy var animator = UIDynamicAnimator()
    
    // Constants
    fileprivate let minimumZoomScale: CGFloat = 1
    fileprivate let minimumVectorDistanceForFlick: CGFloat = 1000
    
    public static func show(_ imageView: UIImageView, presentingVC: UIViewController) {
        let imageViewer = ImageViewer(imageView: imageView, presentingVC: presentingVC)
        imageViewer.presentingVC.present(imageViewer, animated: false, completion: nil)
    }
    
    fileprivate init(imageView: UIImageView, presentingVC: UIViewController) {
        self.originalImageView = imageView
        self.presentingVC = presentingVC
        super.init(nibName: nil, bundle: nil)
        
        self.modalPresentationStyle = .overFullScreen
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadView() {
        super.loadView()
        
        configureViews()
        configureGestures()
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        guard let image = originalImageView.image else { return }
        
        UIView.animate(withDuration: 0.2, animations: {
            self.imageView.frame = self.centerImageOnScreen(image)
        }, completion: { _ in
            self.adjustContentInsets(image)
        })
    }
    
    public override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        guard let image = self.imageView.image else { return }
        coordinator.animate(alongsideTransition: { context in
            self.scrollView.frame = self.view.bounds
            self.imageView.frame = self.centerImageOnScreen(image)
            self.adjustContentInsets(image)
        })
    }
    
    fileprivate func centerImageOnScreen(_ image: UIImage) -> CGRect {
        let imageSize = imageSizeThatFits(image)
        let imageOrigin = CGPoint(x: self.view.frame.size.width/2 - imageSize.width/2, y: self.view.frame.size.height/2 - imageSize.height/2)
        return CGRect(x: imageOrigin.x, y: imageOrigin.y, width: imageSize.width, height: imageSize.height)
    }
    
    fileprivate func imageSizeThatFits(_ image: UIImage) -> CGSize {
        let imageSize = image.size
        var ratio = min(self.view.frame.size.width/imageSize.width, self.view.frame.size.height/imageSize.height)
        ratio = min(ratio, 1.0) //If image smaller than screen, don't make bigger
        return CGSize(width: imageSize.width * ratio, height: imageSize.height * ratio)
    }
    
    fileprivate func adjustContentInsets(_ image: UIImage) {
        let imageSize = self.imageSizeThatFits(image)
        let imageFrame = CGRect(origin: CGPoint.zero, size: imageSize)
        
        scrollView.zoomScale = 1
        scrollView.contentSize = imageSize
        imageView.frame = imageFrame
        
        panGesture?.isEnabled = true // enable because we set zoomscale to 1
        
        let scrollBounds = scrollView.bounds
        var contentOffset = scrollView.contentOffset
        
        if (imageFrame.size.width < scrollBounds.size.width) || (imageFrame.size.height < scrollBounds.size.height) {
            let x = imageView.center.x - (scrollBounds.size.width / 2)
            let y = imageView.center.y - (scrollBounds.size.height / 2)
            contentOffset = CGPoint(x: x, y: y)
        }
        
        var insets = UIEdgeInsets.zero
        
        if scrollBounds.size.width > imageFrame.size.width {
            insets.left = (scrollBounds.size.width - imageFrame.size.width) / 2
            insets.right = insets.left
        }
        
        if scrollBounds.size.height > imageFrame.size.height {
            insets.top = (scrollBounds.size.height - imageFrame.size.height) / 2
            insets.bottom = insets.top
        }
        
        scrollView.contentOffset = contentOffset
        scrollView.contentInset = insets
    }
    
    fileprivate func configureViews() {
        // ImageViewer's view
        self.view = UIView(frame: UIScreen.main.bounds)
        
        // Blur background
        if !UIAccessibilityIsReduceTransparencyEnabled() {
            self.view.backgroundColor = UIColor.clear
            
            let blurEffectView = UIVisualEffectView(effect: UIBlurEffect(style: .light))
            blurEffectView.contentView.isUserInteractionEnabled = true
            blurEffectView.frame = self.view.bounds
            blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            self.blurEffectView = blurEffectView
            self.view.addSubview(blurEffectView)
        } else {
            self.view.backgroundColor = UIColor.black
        }
        
        scrollView.frame = self.view.bounds
        scrollView.delegate = self
        scrollView.minimumZoomScale = minimumZoomScale
        scrollView.maximumZoomScale = calculateMaximumZoomScale()
        scrollView.isScrollEnabled = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        self.view.addSubview(scrollView)
        
        imageView.frame = originalImageView.convert(originalImageView.bounds, to: self.view)
        imageView.image = originalImageView.image
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        imageView.clipsToBounds = true
        imageView.layer.allowsEdgeAntialiasing = true
        scrollView.addSubview(imageView)
        
        animator = UIDynamicAnimator(referenceView: scrollView)
    }
    
    fileprivate func calculateMaximumZoomScale() -> CGFloat {
        guard let imageSize = originalImageView.image?.size else { return 8 }
        let result = (min(imageSize.width, imageSize.height) / min(scrollView.frame.width, scrollView.frame.height) * 4).rounded()
        
        return result > minimumZoomScale ? result : minimumZoomScale + 1
    }
    
    fileprivate func configureGestures() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapImage))
        scrollView.addGestureRecognizer(tap)
        
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(dismissPan))
        panGesture.maximumNumberOfTouches = 1
        self.panGesture = panGesture
        scrollView.addGestureRecognizer(panGesture)
    }
}

// MARK: - ScrollView delegate
extension ImageViewer: UIScrollViewDelegate {
    public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return self.imageView
    }
    
    // When zooming, center the image
    public func scrollViewDidZoom(_ scrollView: UIScrollView) {
        let imageFrame = imageView.frame
        let scrollBounds = scrollView.bounds
        
        var insets = UIEdgeInsets.zero
        
        // Not sure why +1 is needed, but without it when the image is zommed it doesn't bounce when scrolling it
        
        if scrollBounds.size.width > imageFrame.size.width {
            insets.left = ((scrollBounds.size.width - imageFrame.size.width) / 2) + 1
            insets.right = insets.left
        }
        
        if scrollBounds.size.height > imageFrame.size.height {
            insets.top = ((scrollBounds.size.height - imageFrame.size.height) / 2) + 1
            insets.bottom = insets.top
        }
        
        scrollView.contentInset = insets
    }
    
    public func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
        panGesture?.isEnabled = false
    }
    
    public func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        if scale == 1 {
            panGesture?.isEnabled = true
        }
    }
}

// MARK: - Tap gesture methods
extension ImageViewer {
    @objc fileprivate func tapImage(_ sender: UITapGestureRecognizer) {
        UIView.animate(withDuration: 0.2, animations: {
            self.scrollView.contentInset.top = 0 // Needed so it animates nicely into the original UIImageView frame
            self.imageView.frame = self.originalImageView.frame
        }, completion: { finished in self.dismiss(animated: false) })
    }
}

// MARK: - Pan gesture methods
extension ImageViewer {
    @objc fileprivate func dismissPan(_ recognizer: UIPanGestureRecognizer) {
        let touchPoint = recognizer.location(in: recognizer.view)
        let translation = recognizer.translation(in: recognizer.view)
        let velocity = recognizer.velocity(in: recognizer.view)
        let vectorDistance = sqrt(pow(velocity.x, 2) + pow(velocity.y, 2))
        
        switch recognizer.state {
        case .began:
            animator.removeAllBehaviors()
            startImageDragging(touchPoint, translationOffset: .zero)
        case .changed:
            var newAnchor = initialTouchPoint
            newAnchor.x += translation.x + dragOffsetFromTranslation.horizontal
            newAnchor.y += translation.y + dragOffsetFromTranslation.vertical
            attachmentBehavior?.anchorPoint = newAnchor
        case .ended:
            if vectorDistance > minimumVectorDistanceForFlick {
                dismiss(with: velocity)
            } else {
                cancelDrag()
            }
        default:
            break
        }
    }
    
    fileprivate func startImageDragging(_ touchPoint: CGPoint, translationOffset: UIOffset) {
        initialTouchPoint = touchPoint
        dragOffsetFromTranslation = translationOffset
        
        let offset = UIOffset(horizontal: touchPoint.x - imageView.center.x, vertical: touchPoint.y - imageView.center.y)
        let attachmentBehavior = UIAttachmentBehavior(item: imageView, offsetFromCenter: offset, attachedToAnchor: touchPoint)
        self.attachmentBehavior = attachmentBehavior
        animator.addBehavior(attachmentBehavior)
    }
    
    fileprivate func dismiss(with velocity: CGPoint) {
        let pushBehavior = UIPushBehavior(items: [imageView], mode: .instantaneous)
        pushBehavior.pushDirection = CGVector(dx: velocity.x * 0.1, dy: velocity.y * 0.1)
        pushBehavior.setTargetOffsetFromCenter(dragOffsetFromTranslation, for: imageView)
        pushBehavior.action = pushAction
        
        animator.addBehavior(pushBehavior)
        
        if let attachmentBehavior = attachmentBehavior {
            animator.removeBehavior(attachmentBehavior)
        }
    }
    
    fileprivate func pushAction() {
        let visibleRect = scrollView.convert(self.view.bounds, from: self.view)
        let isViewOffscreen = animator.items(in: visibleRect).count == 0
        if isViewOffscreen {
            animator.removeAllBehaviors()
            UIView.animate(withDuration: 0.25, animations: {
                [unowned self] in
                self.view.alpha = 0
                self.blurEffectView?.effect = UIBlurEffect(style: .light)
                }, completion: {
                    finished in
                    self.blurEffectView?.effect = nil
                    self.dismiss(animated: false, completion: nil)
            })
        }
    }
    
    fileprivate func cancelDrag() {
        animator.removeAllBehaviors()
        
        guard let image = self.imageView.image else { return }
        
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut, animations: {
            self.imageView.transform = CGAffineTransform.identity
            self.imageView.frame = self.centerImageOnScreen(image)
            self.adjustContentInsets(image)
        })
    }
}
