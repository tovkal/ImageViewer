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
    fileprivate let originalImageView: UIImageView
    fileprivate let presentingVC: UIViewController
    fileprivate lazy var scrollView = UIScrollView()
    fileprivate lazy var imageView = UIImageView()
    fileprivate var blurEffectView: UIVisualEffectView?
    
    fileprivate lazy var isDraggingImage = false
    fileprivate lazy var initialTouchPoint = CGPoint.zero
    fileprivate lazy var dragOffsetFromTranslation = UIOffset.zero
    fileprivate var attachmentBehavior: UIAttachmentBehavior?
    fileprivate lazy var animator = UIDynamicAnimator()
    
    public static func showImage(imageView: UIImageView, presentingVC: UIViewController) {
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
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        guard let image = originalImageView.image else { return }
        
        imageView.frame = originalImageView.convert(originalImageView.bounds, to: self.view)
        
        UIView.animate(withDuration: 0.2, animations: {
            let imageSize = image.size
            let imageOrigin = CGPoint(x: self.view.frame.size.width/2 - imageSize.width/2,
                                      y: self.view.frame.size.height/2 - imageSize.height/2)
            self.imageView.frame = CGRect(x: imageOrigin.x, y: imageOrigin.y,
                                          width: imageSize.width, height: imageSize.height)
        })
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
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 10
        scrollView.isScrollEnabled = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        self.view.addSubview(scrollView)
        
        imageView.frame = self.view.bounds
        imageView.image = originalImageView.image
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        imageView.clipsToBounds = true
        imageView.layer.allowsEdgeAntialiasing = true
        scrollView.addSubview(imageView)
        
        animator = UIDynamicAnimator(referenceView: scrollView)
    }
    
    fileprivate func configureGestures() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapImage))
        scrollView.addGestureRecognizer(tap)
        
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(dismissPan))
        panGesture.maximumNumberOfTouches = 1
        panGesture.delegate = self
        scrollView.addGestureRecognizer(panGesture)
    }
    
    @objc fileprivate func tapImage(_ sender: UITapGestureRecognizer) {
        UIView.animate(withDuration: 0.2, animations: {
            self.imageView.frame = self.originalImageView.frame
        }, completion: { finished in self.dismiss(animated: false) })
    }
}

extension ImageViewer: UIScrollViewDelegate {
    public func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return self.imageView
    }
    
    // When zooming, center the image
    public func scrollViewDidZoom(_ scrollView: UIScrollView) {
        let horizontalOffset = (scrollView.bounds.size.width > scrollView.contentSize.width) ? ((scrollView.bounds.size.width - scrollView.contentSize.width) * 0.5): 0.0
        let verticalOffset   = (scrollView.bounds.size.height > scrollView.contentSize.height) ? ((scrollView.bounds.size.height - scrollView.contentSize.height) * 0.5): 0.0
        
        imageView.center = CGPoint(x: scrollView.contentSize.width * 0.5 + horizontalOffset, y: scrollView.contentSize.height * 0.5 + verticalOffset)
    }
}

extension ImageViewer: UIGestureRecognizerDelegate {
    @objc fileprivate func dismissPan(_ recognizer: UIPanGestureRecognizer) {
        let touchPoint = recognizer.location(in: recognizer.view)
        let translation = recognizer.translation(in: recognizer.view)
        let velocity = recognizer.velocity(in: recognizer.view)
        let distance = sqrt(pow(velocity.x, 2) + pow(velocity.y, 2))
        
        switch recognizer.state {
        case .began:
            isDraggingImage = imageView.frame.contains(touchPoint)
            if isDraggingImage {
                startImageDragging(touchPoint, translationOffset: .zero)
            }
        case .changed:
            if isDraggingImage {
                var newAnchor = initialTouchPoint
                newAnchor.x += translation.x + dragOffsetFromTranslation.horizontal
                newAnchor.y += translation.y + dragOffsetFromTranslation.vertical
                attachmentBehavior?.anchorPoint = newAnchor
            } else {
                isDraggingImage = imageView.frame.contains(touchPoint)
                if isDraggingImage {
                    let translationOffset = UIOffset(horizontal: -1 * translation.x, vertical: -1 * translation.y)
                    startImageDragging(touchPoint, translationOffset: translationOffset)
                }
            }
        case .ended:
            if distance > 600 {
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
        
        UIViewPropertyAnimator(duration: 0.3, curve: .easeOut, animations: {
            self.imageView.transform = CGAffineTransform.identity
            self.imageView.center = CGPoint(x: self.view.bounds.width / 2,
                                            y: self.view.bounds.height / 2)
        }).startAnimation()
    }
}
