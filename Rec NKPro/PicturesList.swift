//
//  PicturesList.swift
//  Rec NKPro
//
//  Created by NK on 05.04.16.
//  Copyright © 2016 Nikolay Kolesnikov. All rights reserved.
//

import UIKit

let DocumentsDirectory = NSFileManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first!
let archiveURL = DocumentsDirectory.URLByAppendingPathComponent("pictures")

class PicturesList {
  
  static let pList = PicturesList()
  
  var pictures: [Picture]
  
  init() {
    if let pictures = NSKeyedUnarchiver.unarchiveObjectWithFile(archiveURL.path!) as? [Picture] {
      self.pictures = pictures
    } else {
      self.pictures = [Picture]()
    }
  }
  
  func savePictures() {
    let isSuccessfulSave = NSKeyedArchiver.archiveRootObject(pictures, toFile: archiveURL.path!)
    if !isSuccessfulSave {
      print("Failed to save pictures...")
    } else {
      print("Pictures saved")
    }
  }


}
