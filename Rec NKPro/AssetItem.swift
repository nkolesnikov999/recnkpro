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
  var size: UInt64 = 0
  var url: URL
  var image: UIImage?
  var isLocked: Bool = false
  
  init(title: String) {
    self.title = title
    
    let movieString = NSString(format: "%@%@", NSTemporaryDirectory(), title) as String
    url = URL(fileURLWithPath: movieString)
    
    let fileManager = FileManager.default
    
    do {
      let fileAttributes = try fileManager.attributesOfItem(atPath: movieString)
      if let fileSizeNumber = fileAttributes[.size] as? NSNumber {
        size = fileSizeNumber.uint64Value
      }
    } catch let error as NSError {
      print("ERROR: AssetsItem.sizeFile - \(error.debugDescription)")
    }
    
    image = UIImage(named: "Placeholder")
    generateImage()
    
    if LockedList.lockList.lockVideo.contains(title) {
      isLocked = true
    }
  }
  
  func generateImage() {
    let asset = AVAsset(url: url)
    let imageTimeValue = NSValue(time: CMTimeMake(2, 1))
    let imageGenerator = AVAssetImageGenerator(asset: asset)
    let maxSize = CGSize(width: 192, height: 192)
    imageGenerator.maximumSize = maxSize
    imageGenerator.appliesPreferredTrackTransform = true
    imageGenerator.generateCGImagesAsynchronously(forTimes: [imageTimeValue], completionHandler: { (requestedTime, image, actualTime, result, error) -> Void in
      if let cgImage = image {
        let uiImage = self.copyImageFromCGImage(cgImage)
        if let image = uiImage {
          self.image = image
        }
      }
    })
  }
  
  func copyImageFromCGImage(_ image: CGImage) -> UIImage? {
  
    var thumbUIImage: UIImage? = nil
    let thumbRect = CGRect(x: 0, y: 0, width: CGFloat(image.width), height: CGFloat(image.height))
    let size = CGSize(width: 96, height: 96)
    var cropRect = AVMakeRect(aspectRatio: size, insideRect: thumbRect)
    cropRect.origin.x = round(cropRect.origin.x)
    cropRect.origin.y = round(cropRect.origin.y)
    cropRect = cropRect.integral
    let croppedThumbImage = image.cropping(to: cropRect)
    if let image = croppedThumbImage {
      thumbUIImage = UIImage(cgImage: image)
    }
    
    return thumbUIImage
  }

  
}
