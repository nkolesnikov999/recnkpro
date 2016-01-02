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
  
  var distance: Int
  var location: CLLocation?
  
  init(distance: Int) {
    self.distance = distance
    
  }
  
  func distanceUpdate(newLocation: CLLocation) -> Int? {
    
    if let location = location {
      
      let delta = Int(newLocation.distanceFromLocation(location))
      if delta > 20 {
        self.location = newLocation
        distance += delta
        NSUserDefaults.standardUserDefaults().setValue(distance, forKey: OdometerMetersKey)
        return distance
      }
    } else {
      location = newLocation
    }
    
    return nil
  }

}
