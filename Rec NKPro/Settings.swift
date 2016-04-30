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
  var frontQualityMode: QualityMode = .Medium
  var backQualityMode: QualityMode = .Medium
  var typeCamera: TypeCamera = .Back
  var autofocusing: Bool = true
  var textOnVideo: Bool = true
  var logotype: String = "NKPRO.NET"
  var minIntervalLocations: Int = 0
  var typeSpeed: TypeSpeed = .Km
  var maxRecordingTime: Int = 5
  var maxNumberVideo: Int = 2
  var intervalPictures: Int = 60
  var odometerMeters: Int = 0
}
