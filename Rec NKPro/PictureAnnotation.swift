//
//  PictureAnnotation.swift
//  Rec NKPro
//
//  Created by NK on 08.04.16.
//  Copyright © 2016 Nikolay Kolesnikov. All rights reserved.
//

import UIKit
import MapKit

class PictureAnnotation: NSObject, MKAnnotation {

  var pictureIndex: Int!
  var location: CLLocation!
  var title: String?
  
  var coordinate: CLLocationCoordinate2D {
    return location.coordinate
  }
  
}
