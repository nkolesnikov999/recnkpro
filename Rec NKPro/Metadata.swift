//
//  Metadata.swift
//  Rec NKPro
//
//  Created by NK on 10.01.16.
//  Copyright © 2016 Nikolay Kolesnikov. All rights reserved.
//

import UIKit
import CoreMedia
import CoreLocation

class Metadata {
  var timestamp: CMTimeRange?
  var location: CLLocation?
  var speed: String = ""
  var time: String = ""
}
