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
    }
}
