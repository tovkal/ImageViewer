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
    fileprivate lazy var scrollView = UIScrollView()
    fileprivate lazy var imageView = UIImageView()
    
    fileprivate lazy var isDraggingImage = false
    fileprivate lazy var initialTouchPoint = CGPoint.zero
    fileprivate lazy var attachmentBehavior = UIAttachmentBehavior()
    fileprivate lazy var animator = UIDynamicAnimator()
    
    static func showImage(imageView: UIImageView, presentingVC: UIViewController) {
        let imageViewer = ImageViewer(imageView: imageView, presentingVC: presentingVC)
        imageViewer.presentingVC.present(imageViewer, animated: false, completion: nil)
    }
    
    init(imageView: UIImageView, presentingVC: UIViewController) {
        self.originalImageView = imageView
        self.presentingVC = presentingVC
        super.init(nibName: nil, bundle: nil)
        
        self.modalPresentationStyle = .overFullScreen
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        super.loadView()
        
        configureViews()
        configureGestures()
    }
    
    override func viewWillAppear(_ animated: Bool) {
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
            
            self.view.addSubview(blurEffectView)
        } else {
            self.view.backgroundColor = UIColor.black
        }
        
        scrollView.frame = self.view.bounds
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
    }
    
    fileprivate func configureGestures() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(ImageViewer.tapImage(_:)))
        scrollView.addGestureRecognizer(tap)
        
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(ImageViewer.dismissPan(_:)))
        panGesture.maximumNumberOfTouches = 1
        panGesture.delegate = self
        scrollView.addGestureRecognizer(panGesture)
    }
    
    func tapImage(_ sender: UITapGestureRecognizer) {
        UIView.animate(withDuration: 0.2, animations: {
            self.imageView.frame = self.originalImageView.frame
        }, completion: { finished in self.dismiss(animated: false) })
    }
}

extension ImageViewer: UIGestureRecognizerDelegate {
    func dismissPan(_ recognizer: UIPanGestureRecognizer) {
        let touchPoint = recognizer.location(in: recognizer.view)
        let translation = recognizer.translation(in: recognizer.view)
        
        switch recognizer.state {
        case .began:
            isDraggingImage = imageView.frame.contains(touchPoint)
            if isDraggingImage {
                initialTouchPoint = touchPoint
                let offset = UIOffset(horizontal: touchPoint.x - imageView.center.x, vertical: touchPoint.y - imageView.center.y)
                attachmentBehavior = UIAttachmentBehavior(item: imageView, offsetFromCenter: offset, attachedToAnchor: touchPoint)
                animator.addBehavior(attachmentBehavior)
            }
        case .changed:
            var newAnchor = initialTouchPoint
            newAnchor.x += translation.x
            newAnchor.y += translation.y
            attachmentBehavior.anchorPoint = newAnchor
        case .ended:
            isDraggingImage = false
            initialTouchPoint = .zero
            animator.removeAllBehaviors()
            
            UIViewPropertyAnimator(duration: 0.3, curve: .easeOut, animations: {
                self.imageView.transform = CGAffineTransform.identity
                self.imageView.center = CGPoint(x: self.view.bounds.width / 2,
                                                y: self.view.bounds.height / 2)
            }).startAnimation()
            break
        default:
            break
        }
    }
}
