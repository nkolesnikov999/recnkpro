//
//  Metadata.swift
//  Rec NKPro
//
//  Created by NK on 10.01.16.
//  Copyright © 2016 Nikolay Kolesnikov. All rights reserved.
//

import UIKit
import MapKit
import CoreMedia
import CoreLocation

class Metadata: NSObject, MKAnnotation {
  var timestamp: CMTimeRange?
  var location: CLLocation?
  var speed: String = ""
  var time: String = ""
  
  var coordinate: CLLocationCoordinate2D {
    return location!.coordinate
  }
  
  var title: String? {
    return time
  }
  
}
