//
//  FrameRateCalculator.swift
//  Rec NKPro
//
//  Created by NK on 03.01.16.
//  Copyright © 2016 Nikolay Kolesnikov. All rights reserved.
//

import UIKit
import CoreMedia

class FrameRateCalculator {
  
  var frameRate: Float
  var previousSecondTimestamps: [CMTime]
  
  init() {
    frameRate = 0.0
    previousSecondTimestamps = [CMTime]()
  }
  
  func reset() {
    previousSecondTimestamps.removeAll()
    frameRate = 0.0
  }
  
  func calculateFramerateAtTimestamp(_ timestamp: CMTime) {
    previousSecondTimestamps.append(timestamp)
    
    let oneSecond = CMTimeMake(1, 1)
    let oneSecondAgo = CMTimeSubtract(timestamp, oneSecond)
    
    while CMTimeCompare(previousSecondTimestamps.first!, oneSecondAgo) < 0 {
      previousSecondTimestamps.removeFirst()
    }
    
    let newRate = Float(previousSecondTimestamps.count)
    frameRate = (frameRate + newRate) / 2
  }
}
