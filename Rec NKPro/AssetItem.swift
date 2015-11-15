//
//  AssetItem.swift
//  FixDrive
//
//  Created by NK on 07.11.15.
//  Copyright © 2015 Nikolay Kolesnikov. All rights reserved.
//

import UIKit
import AVFoundation

class AssetItem {
  var title: String
  var size: Int = 0
  var url: NSURL
  var image: UIImage?
  
  init(title: String) {
    self.title = title
    
    let movieString = NSString(format: "%@%@", NSTemporaryDirectory(), title) as String
    url = NSURL.fileURLWithPath(movieString)
    
    let fileManager = NSFileManager.defaultManager()
    
    do {
      let dictionary = try fileManager.attributesOfItemAtPath(movieString)
      
      size = dictionary["NSFileSize"] as! Int
    } catch {
      let nserror = error as NSError
      print("ERROR: AssetsItem.sizeFile - \(nserror.userInfo)")
    }
    image = UIImage(named: "Placeholder")
    generateImage()
  }
  
  func generateImage() {
    let asset = AVAsset(URL: url)
    let imageTimeValue = NSValue(CMTime: CMTimeMake(2, 1))
    let imageGenerator = AVAssetImageGenerator(asset: asset)
    let maxSize = CGSize(width: 192, height: 192)
    imageGenerator.maximumSize = maxSize
    imageGenerator.appliesPreferredTrackTransform = true
    imageGenerator.generateCGImagesAsynchronouslyForTimes([imageTimeValue], completionHandler: { (requestedTime, image, actualTime, result, error) -> Void in
      if let cgImage = image {
        let uiImage = self.copyImageFromCGImage(cgImage)
        if let image = uiImage {
          self.image = image
        }
      }
    })
  }
  
  func copyImageFromCGImage(image: CGImageRef) -> UIImage? {
  
    var thumbUIImage: UIImage? = nil
    let thumbRect = CGRectMake(0, 0, CGFloat(CGImageGetWidth(image)), CGFloat(CGImageGetHeight(image)))
    let size = CGSize(width: 96, height: 64)
    var cropRect = AVMakeRectWithAspectRatioInsideRect(size, thumbRect)
    cropRect.origin.x = round(cropRect.origin.x)
    cropRect.origin.y = round(cropRect.origin.y)
    cropRect = CGRectIntegral(cropRect)
    let croppedThumbImage = CGImageCreateWithImageInRect(image, cropRect)
    if let image = croppedThumbImage {
      thumbUIImage = UIImage(CGImage: image)
    }
    
    return thumbUIImage
  }

  
}
