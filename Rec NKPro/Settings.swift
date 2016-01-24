//
//  Settings.swift
//  FixDrive
//
//  Created by NK on 11.11.15.
//  Copyright © 2015 Nikolay Kolesnikov. All rights reserved.
//

import Foundation

enum QualityMode : Int {
  case Low = 0
  case Medium = 1
  case High = 2
}

enum TypeCamera: Int {
  case Front = 0
  case Back = 1
}

enum TypeSpeed: Int {
  case Km = 0
  case Mi = 1
}

class Settings {
  var qualityMode: QualityMode = .Medium
  var typeCamera: TypeCamera = .Back
  var autofocusing: Bool = false
  var textOnVideo: Bool = true
  var logotype: String = "NKPRO.NET"
  var minIntervalLocations: Int = 0
  var typeSpeed: TypeSpeed = .Km
  var maxRecordingTime: Int = 30
  var maxNumberFiles: Int = 2
  var odometerMeters: Int = 0
}
