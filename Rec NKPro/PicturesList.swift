//
//  PicturesList.swift
//  Rec NKPro
//
//  Created by NK on 05.04.16.
//  Copyright © 2016 Nikolay Kolesnikov. All rights reserved.
//

import UIKit

let DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
let archiveURL = DocumentsDirectory.appendingPathComponent("pictures")

class PicturesList {
  
  static let pList = PicturesList()
  
  var savePicturesQueue: DispatchQueue!
  var pictures: [Picture]
  
  init() {
    savePicturesQueue = DispatchQueue(label: "net.nkpro.fixdrive.savePictures.queue", attributes: DispatchQueue.Attributes.concurrent)
    if let pictures = NSKeyedUnarchiver.unarchiveObject(withFile: archiveURL.path) as? [Picture] {
      self.pictures = pictures
    } else {
      self.pictures = [Picture]()
    }
  }
  
  func savePictures() {
    savePicturesQueue.async {
      let isSuccessfulSave = NSKeyedArchiver.archiveRootObject(self.pictures, toFile: archiveURL.path)
      if !isSuccessfulSave {
        print("Failed to save pictures...")
      } else {
        //print("Pictures saved")
      }
    }
  }

}
