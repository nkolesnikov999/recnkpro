//
//  ZoomedPhotoViewController.swift
//  Rec NKPro
//
//  Created by NK on 01.04.16.
//  Copyright © 2016 Nikolay Kolesnikov. All rights reserved.
//


import UIKit

class ZoomedPhotoViewController: UIViewController {
  @IBOutlet weak var scrollView: UIScrollView!
  @IBOutlet weak var imageViewBottomConstraint: NSLayoutConstraint!
  @IBOutlet weak var imageViewLeadingConstraint: NSLayoutConstraint!
  @IBOutlet weak var imageViewTopConstraint: NSLayoutConstraint!
  @IBOutlet weak var imageViewTrailingConstraint: NSLayoutConstraint!
  @IBOutlet weak var imageView: UIImageView!
  var image: UIImage!
  
  override func viewDidLoad() {
    imageView.image = image
  }
  
  override func viewDidAppear(animated: Bool) {
    super.viewDidAppear(animated)
    //print("imageView: \(imageView.bounds.width), \(imageView.bounds.height)")
  }
  
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    updateConstraintsForSize(view.bounds.size)
    updateMinZoomScaleForSize(view.bounds.size)
  }
  
  override func prefersStatusBarHidden() -> Bool {
    
    return true
  }

  
  @IBAction func tapBack(sender: UIButton) {
    dismissViewControllerAnimated(false, completion: nil)
  }
  
  private func updateMinZoomScaleForSize(size: CGSize) {
    
    let widthScale = size.width / imageView.bounds.width
    let heightScale = size.height / imageView.bounds.height
    let minScale = min(widthScale, heightScale)
    
    scrollView.minimumZoomScale = minScale
    scrollView.maximumZoomScale = 10
    scrollView.zoomScale = minScale
  }
  
  private func updateConstraintsForSize(size: CGSize) {
    
    let yOffset = max(0, (size.height - imageView.frame.height) / 2)
    imageViewTopConstraint.constant = yOffset
    imageViewBottomConstraint.constant = yOffset
    
    let xOffset = max(0, (size.width - imageView.frame.width) / 2)
    imageViewLeadingConstraint.constant = xOffset
    imageViewTrailingConstraint.constant = xOffset
    
    //print("xOffset: \(xOffset),  yOffset: \(yOffset)")
    view.layoutIfNeeded()
  }
  
}

extension ZoomedPhotoViewController: UIScrollViewDelegate {
  func viewForZoomingInScrollView(scrollView: UIScrollView) -> UIView? {
    return imageView
  }
  
  func scrollViewDidZoom(scrollView: UIScrollView) {
    updateConstraintsForSize(view.bounds.size)
    //print("imageView: \(imageView.bounds.width), \(imageView.bounds.height)")
  }
}


