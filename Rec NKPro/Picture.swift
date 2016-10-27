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
  
  var date: Date
  var photoPath: URL!
  var thumb80: UIImage!
  var address: String = " "
  var location: CLLocation?
  
  var title: String {
    let dateFormater = DateFormatter()
    dateFormater.dateFormat = "yyMMdd_HHmmssSS"
    return dateFormater.string(from: date)
  }
  
  // MARK: Archiving Paths
  
  let photoPathKey = "photoPathKey"
  let dateKey = "phdateKeyoto"
  let thumb80Key = "thumb80Key"
  let addressKey = "addressKey"
  let locationKey = "locationKey"
  
  
  init?(image: UIImage, date: Date, location: CLLocation?) {
    self.date = date
    self.location = location
    self.thumb80 = image.thumbnailOfSize(CGSize(width: 80, height: 80))
    
    super.init()
    
    self.photoPath = createURLFromDate(date)
    if !saveImage(image, path: photoPath.path) {
      return nil
    }
    findAddress(location)
  }

  
  // MARK: NSCoding
  
  required init(coder aDecoder: NSCoder) {
    self.date = aDecoder.decodeObject(forKey: dateKey) as! Date
    self.photoPath = aDecoder.decodeObject(forKey: photoPathKey) as!  URL
    self.thumb80 = aDecoder.decodeObject(forKey: thumb80Key) as! UIImage
    self.location = aDecoder.decodeObject(forKey: locationKey) as? CLLocation
    self.address = aDecoder.decodeObject(forKey: addressKey) as! String
    super.init()
    if address == " " {
      findAddress(self.location)
    }
  }
  
  
  func encode(with aCoder: NSCoder) {
    aCoder.encode(date, forKey: dateKey)
    aCoder.encode(photoPath, forKey: photoPathKey)
    aCoder.encode(thumb80, forKey: thumb80Key)
    aCoder.encode(address, forKey: addressKey)
    aCoder.encode(location, forKey: locationKey)
  }
  
  // MARK: Utilities
  
  func saveImage(_ image: UIImage, path: String ) -> Bool{
    var result = false
    if let pngImageData = UIImageJPEGRepresentation(image, 1.0) {
      result = (try? pngImageData.write(to: URL(fileURLWithPath: path), options: [.atomic])) != nil
    }
    return result
  }
  
  
  func loadImage() -> UIImage? {
    //guard let path = photoPath.path else { return nil }
    let directory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
    let path = directory.appendingPathComponent(title).path
    
    let image = UIImage(contentsOfFile: path)
    if image == nil {
      print("missing image at: \(path)")
    } else {
      //print("Loading image from path: \(path)")
    }
    
    return image
  }
  
  
  func createURLFromDate(_ date: Date) -> URL {
    //print("Picture.createURLFromDate")
    let directory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
    return directory.appendingPathComponent(title)
  }
  
  func findAddress(_ location: CLLocation?) {
    guard let location = location else { return }
    
    let geoCoder = CLGeocoder()
    geoCoder.reverseGeocodeLocation(location, completionHandler: { (placemarks, error) -> Void in
      
      if let placemarks = placemarks {
        if placemarks.count > 0 {
          let placemark = placemarks[0]
          
          if let city = placemark.addressDictionary?["City"] as? String {
            self.address = city
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
