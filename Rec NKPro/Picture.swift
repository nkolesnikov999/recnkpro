//
//  Picture.swift
//  Rec NKPro
//
//  Created by NK on 01.04.16.
//  Copyright © 2016 Nikolay Kolesnikov. All rights reserved.
//

import UIKit
import CoreLocation

class Picture: NSObject, NSCoding {
  
  var date: NSDate
  var photoPath: NSURL!
  var thumb80: UIImage!
  var address: String = " "
  var location: CLLocation?
  
  var title: String {
    let dateFormater = NSDateFormatter()
    dateFormater.dateFormat = "yyMMdd_HHmmssSS"
    return dateFormater.stringFromDate(date)
  }
  
  // MARK: Archiving Paths
  
  let photoPathKey = "photoPathKey"
  let dateKey = "phdateKeyoto"
  let thumb80Key = "thumb80Key"
  let addressKey = "addressKey"
  let locationKey = "locationKey"
  
  
  init?(image: UIImage, date: NSDate, location: CLLocation?) {
    self.date = date
    self.location = location
    self.thumb80 = image.thumbnailOfSize(CGSize(width: 80, height: 80))
    
    super.init()
    
    self.photoPath = createURLFromDate(date)
    if !saveImage(image, path: photoPath.path!) {
      return nil
    }
    findAddress(location)
  }

  
  // MARK: NSCoding
  
  required init(coder aDecoder: NSCoder) {
    self.date = aDecoder.decodeObjectForKey(dateKey) as! NSDate
    self.photoPath = aDecoder.decodeObjectForKey(photoPathKey) as!  NSURL
    self.thumb80 = aDecoder.decodeObjectForKey(thumb80Key) as! UIImage
    self.location = aDecoder.decodeObjectForKey(locationKey) as? CLLocation
    self.address = aDecoder.decodeObjectForKey(addressKey) as! String
    super.init()
    if address == " " {
      findAddress(self.location)
    }
  }
  
  
  func encodeWithCoder(aCoder: NSCoder) {
    aCoder.encodeObject(date, forKey: dateKey)
    aCoder.encodeObject(photoPath, forKey: photoPathKey)
    aCoder.encodeObject(thumb80, forKey: thumb80Key)
    aCoder.encodeObject(address, forKey: addressKey)
    aCoder.encodeObject(location, forKey: locationKey)
  }
  
  // MARK: Utilities
  
  func saveImage(image: UIImage, path: String ) -> Bool{
    var result = false
    if let pngImageData = UIImageJPEGRepresentation(image, 1.0) {
      result = pngImageData.writeToFile(path, atomically: true)
    }
    return result
  }
  
  
  func loadImage() -> UIImage? {
    //guard let path = photoPath.path else { return nil }
    let directory = NSFileManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first!
    guard let path = directory.URLByAppendingPathComponent(title).path else { return nil }
    
    let image = UIImage(contentsOfFile: path)
    if image == nil {
      print("missing image at: \(path)")
    } else {
      //print("Loading image from path: \(path)")
    }
    
    return image
  }
  
  
  func createURLFromDate(date: NSDate) -> NSURL {
    //print("Picture.createURLFromDate")
    let directory = NSFileManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first!
    return directory.URLByAppendingPathComponent(title)
  }
  
  func findAddress(location: CLLocation?) {
    guard let location = location else { return }
    
    let geoCoder = CLGeocoder()
    geoCoder.reverseGeocodeLocation(location, completionHandler: { (placemarks, error) -> Void in
      
      if let placemarks = placemarks {
        if placemarks.count > 0 {
          let placemark = placemarks[0]
          
          if let city = placemark.addressDictionary?["City"] as? String {
            self.address += city
          }
          
          if let locationName = placemark.addressDictionary?["Name"] as? String {
            self.address = self.address + "\n" + locationName
          }
          
          /*
          // Address dictionary
          print(placemark.addressDictionary)
          
          // Location name
          if let locationName = placemark.addressDictionary?["Name"] as? NSString {
            print(locationName)
          }
          
          // Street address
          if let street = placemark.addressDictionary?["Thoroughfare"] as? NSString {
            print(street)
          }
          
          // City
          if let city = placemark.addressDictionary?["City"] as? NSString {
            print(city)
          }
          
          // Zip code
          if let zip = placemark.addressDictionary?["ZIP"] as? NSString {
            print(zip)
          }
          
          // Country
          if let country = placemark.addressDictionary?["Country"] as? NSString {
            print(country)
          }
          */
        }
      }
      
      
    })
  }

}
