//
//  SettingsViewController.swift
//  FixDrive
//
//  Created by NK on 08.11.15.
//  Copyright © 2015 Nikolay Kolesnikov. All rights reserved.
//

/*
*
*
* http://stackoverflow.com/questions/26028918/ios-how-to-determine-iphone-model-in-swift
*
*
*/

import UIKit

protocol SettingsControllerDelegate: class {
  
  func saveSettings()
  
}

class SettingsViewController: UITableViewController {
  
  weak var delegate: SettingsControllerDelegate?
  var settings: Settings!
  
  @IBOutlet weak var qualityModeSegment: UISegmentedControl!
  @IBOutlet weak var typeCameraSegment: UISegmentedControl!
  @IBOutlet weak var autofocusingSwitch: UISwitch!
  @IBOutlet weak var minIntervalLabel: UILabel!
  @IBOutlet weak var minIntervalSlider: UISlider!
  @IBOutlet weak var typeSpeedSegment: UISegmentedControl!
  @IBOutlet weak var maxRecordingTimeLabel: UILabel!
  @IBOutlet weak var maxRecordingTimeSlider: UISlider!
  @IBOutlet weak var maxNumberFilesLabel: UILabel!
  @IBOutlet weak var maxNumberFilesSlider: UISlider!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    let modelName = UIDevice.currentDevice().modelName
    
    if modelName == "iPhone 4s" {
      qualityModeSegment.removeSegmentAtIndex(2, animated: false)
    }
    
    setAllControls()
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  override func prefersStatusBarHidden() -> Bool {
    
    return true
  }
  
  // MARK: - Actions
  
  @IBAction func tapBackButton(sender: UIBarButtonItem) {
    delegate?.saveSettings()
    dismissViewControllerAnimated(true, completion: nil)
  }

  @IBAction func selectQualityMode(sender: UISegmentedControl) {
    settings.qualityMode = QualityMode(rawValue:  sender.selectedSegmentIndex)!
  }
  
  @IBAction func selectTypeCamera(sender: UISegmentedControl) {
    settings.typeCamera = TypeCamera(rawValue: sender.selectedSegmentIndex)!
  }
  
  @IBAction func selectAutofocusing(sender: UISwitch) {
    settings.autofocusing = sender.on
  }
  
  @IBAction func setMinInterval(sender: UISlider) {
    let partValue = sender.value/10
    let value = Int(partValue) * 10
    sender.value = Float(value)
    minIntervalLabel.text = String(format: NSLocalizedString("%d m", comment: "SettingsVC Format for minIntervalLabel"), value)
    settings.minIntervalLocations = value
  }
  
  @IBAction func setTypeSpeed(sender: UISegmentedControl) {
    settings.typeSpeed = TypeSpeed(rawValue: sender.selectedSegmentIndex)!
  }
  
  @IBAction func setMaxRecordingTime(sender: UISlider) {
    let partValue = sender.value/5
    let value = Int(partValue) * 5
    sender.value = Float(value)
    maxRecordingTimeLabel.text =  String(format: NSLocalizedString("%d min", comment: "SettingsVC Format for maxRecordingTimeLabel"), value)

    settings.maxRecordingTime = value
  }
  
  @IBAction func setMaxNumberFiles(sender: UISlider) {
    let value = Int(sender.value)
    sender.value = Float(value)
    maxNumberFilesLabel.text = "\(value)"
    settings.maxNumberFiles = value
  }
  
  @IBAction func resetOdometer(sender: AnyObject) {
    settings.odometerMeters = 0
  }
  
  @IBAction func setDefaultSettings(sender: AnyObject) {
    let new = Settings()
    
    settings.qualityMode = new.qualityMode
    settings.typeCamera = new.typeCamera
    settings.autofocusing = new.autofocusing
    settings.minIntervalLocations = new.minIntervalLocations
    settings.maxRecordingTime = new.maxRecordingTime
    settings.maxNumberFiles = new.maxNumberFiles

    setAllControls()
  }
  
  func setAllControls() {
    qualityModeSegment.selectedSegmentIndex = settings.qualityMode.rawValue
    typeCameraSegment.selectedSegmentIndex = settings.typeCamera.rawValue
    autofocusingSwitch.on = settings.autofocusing
    minIntervalSlider.value = Float(settings.minIntervalLocations)
    typeSpeedSegment.selectedSegmentIndex = settings.typeSpeed.rawValue
    maxRecordingTimeSlider.value = Float(settings.maxRecordingTime)
    maxNumberFilesSlider.value = Float(settings.maxNumberFiles)
    
    minIntervalLabel.text = String(format: NSLocalizedString("%d m", comment: "SettingsVC Format for minIntervalLabel"), settings.minIntervalLocations)
    maxRecordingTimeLabel.text = String(format: NSLocalizedString("%d min", comment: "SettingsVC Format for maxRecordingTimeLabel"), settings.maxRecordingTime)
    maxNumberFilesLabel.text = "\(settings.maxNumberFiles)"
  }
  
  
}



public extension UIDevice {
  
  var modelName: String {
    var systemInfo = utsname()
    uname(&systemInfo)
    let machineMirror = Mirror(reflecting: systemInfo.machine)
    let identifier = machineMirror.children.reduce("") { identifier, element in
      guard let value = element.value as? Int8 where value != 0 else { return identifier }
      return identifier + String(UnicodeScalar(UInt8(value)))
    }
    
    switch identifier {
    case "iPod5,1":                                 return "iPod Touch 5"
    case "iPod7,1":                                 return "iPod Touch 6"
    case "iPhone3,1", "iPhone3,2", "iPhone3,3":     return "iPhone 4"
    case "iPhone4,1":                               return "iPhone 4s"
    case "iPhone5,1", "iPhone5,2":                  return "iPhone 5"
    case "iPhone5,3", "iPhone5,4":                  return "iPhone 5c"
    case "iPhone6,1", "iPhone6,2":                  return "iPhone 5s"
    case "iPhone7,2":                               return "iPhone 6"
    case "iPhone7,1":                               return "iPhone 6 Plus"
    case "iPhone8,1":                               return "iPhone 6s"
    case "iPhone8,2":                               return "iPhone 6s Plus"
    case "iPad2,1", "iPad2,2", "iPad2,3", "iPad2,4":return "iPad 2"
    case "iPad3,1", "iPad3,2", "iPad3,3":           return "iPad 3"
    case "iPad3,4", "iPad3,5", "iPad3,6":           return "iPad 4"
    case "iPad4,1", "iPad4,2", "iPad4,3":           return "iPad Air"
    case "iPad5,3", "iPad5,4":                      return "iPad Air 2"
    case "iPad2,5", "iPad2,6", "iPad2,7":           return "iPad Mini"
    case "iPad4,4", "iPad4,5", "iPad4,6":           return "iPad Mini 2"
    case "iPad4,7", "iPad4,8", "iPad4,9":           return "iPad Mini 3"
    case "iPad5,1", "iPad5,2":                      return "iPad Mini 4"
    case "iPad6,7", "iPad6,8":                      return "iPad Pro"
    case "AppleTV5,3":                              return "Apple TV"
    case "i386", "x86_64":                          return "Simulator"
    default:                                        return identifier
    }
  }
  
}

