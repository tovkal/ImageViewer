//
//  ViewController.swift
//  ImageViewer
//
//  Created by Andrés Pizá Bückmann on 04/06/2017.
//  Copyright © 2017 Andrés Pizá Bückmann. All rights reserved.
//

import UIKit
import ImageViewer

class ViewController: UIViewController {
    
    @IBOutlet weak var imageView: UIImageView!
    
    override func viewDidLoad() {
        self.imageView.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.didTapImage(_:)))
        self.imageView.addGestureRecognizer(tap)
    }
    
    @IBAction func didTapImage(_ sender: UITapGestureRecognizer) {
        ImageViewer.showImage(imageView: imageView, presentingVC: self)
    }
}

