//
//  Settings.swift
//  FixDrive
//
//  Created by NK on 11.11.15.
//  Copyright © 2015 Nikolay Kolesnikov. All rights reserved.
//

import Foundation

enum QualityMode : Int {
  case low = 0
  case medium = 1
  case high = 2
}

enum TypeCamera: Int {
  case front = 0
  case back = 1
}

enum TypeSpeed: Int {
  case km = 0
  case mi = 1
}

class Settings {
  var frontQualityMode: QualityMode = .low
  var backQualityMode: QualityMode = .low
  var typeCamera: TypeCamera = .back
  var autofocusing: Bool = true
  var textOnVideo: Bool = true
  var logotype: String = "NKPRO.NET"
  var minIntervalLocations: Int = 0
  var typeSpeed: TypeSpeed = .km
  var maxRecordingTime: Int = 1
  var maxNumberVideo: Int = 2
  var intervalPictures: Int = 60
  var odometerMeters: Int = 0
  var isMicOn: Bool = true
}
