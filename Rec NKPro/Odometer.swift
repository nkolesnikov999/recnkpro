//
//  Odometer.swift
//  Rec NKPro
//
//  Created by NK on 02.01.16.
//  Copyright © 2016 Nikolay Kolesnikov. All rights reserved.
//

import UIKit
import CoreLocation

class Odometer {
  
  static let accuracity = 50
  var distance: Int
  var location: CLLocation?
  
  init(distance: Int) {
    self.distance = distance
  }
  
  func distanceUpdate(newLocation: CLLocation) -> Int? {
    
    if let location = location {
      let delta = Int(newLocation.distanceFromLocation(location))
      if delta > Odometer.accuracity {
        self.location = newLocation
        distance += delta
        save()
        return distance
      }
    } else {
      location = newLocation
    }
    return nil
  }
  
  func stop() {
    location = nil
  }
  
  func reset() {
    distance = 0
    save()
  }
  
  func save() {
    NSUserDefaults.standardUserDefaults().setValue(distance, forKey: OdometerMetersKey)
  }

}
