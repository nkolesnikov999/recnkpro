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
import StoreKit

protocol SettingsControllerDelegate: class {
  
  func saveSettings()
  
}

class SettingsViewController: UITableViewController {
  
  let logo5000distance: Int = 5_000_000
  let logo1000distance: Int = 1_000_000
  
  private var removeAdProduct: SKProduct?
  private var changeLogoProduct: SKProduct?
  
  weak var delegate: SettingsControllerDelegate?
  var settings: Settings!
  
  var numberAssetFiles = 0
  var oldSettingNumberFiles = 0
  
  @IBOutlet weak var qualityModeSegment: UISegmentedControl!
  @IBOutlet weak var typeCameraSegment: UISegmentedControl!
  @IBOutlet weak var autofocusingSwitch: UISwitch!
  @IBOutlet weak var textOnVideoSwitch: UISwitch!
  @IBOutlet weak var minIntervalLabel: UILabel!
  @IBOutlet weak var minIntervalSlider: UISlider!
  @IBOutlet weak var typeSpeedSegment: UISegmentedControl!
  @IBOutlet weak var maxRecordingTimeLabel: UILabel!
  @IBOutlet weak var maxRecordingTimeSlider: UISlider!
  @IBOutlet weak var maxNumberFilesLabel: UILabel!
  @IBOutlet weak var maxNumberFilesSlider: UISlider!
  @IBOutlet weak var logotypeTextField: UITextField!
  @IBOutlet weak var changeLogoButton: UIButton!
  @IBOutlet weak var removeAdsButton: UIButton!
  @IBOutlet weak var restorePurchasesButton: UIButton!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    let modelName = UIDevice.currentDevice().modelName
    
    if modelName == "iPhone 4s" {
      //qualityModeSegment.removeSegmentAtIndex(2, animated: false)
    }
    
    changeLogoButton.enabled = false
    removeAdsButton.enabled = false
    
    logotypeTextField.delegate = self
    
    setAllControls()
    
    //print("Distance: \(settings.odometerMeters)")
    //settings.odometerMeters = 1_000_001
    
    requestIAPProducts()
    NSNotificationCenter.defaultCenter().addObserver(self, selector: "handlePurchaseNotification:", name: IAPHelper.IAPHelperPurchaseNotification, object: nil)
    checkStateRestoreButton()
    
    oldSettingNumberFiles = settings.maxNumberFiles
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  override func prefersStatusBarHidden() -> Bool {
    
    return true
  }
  
  deinit {
    NSNotificationCenter.defaultCenter().removeObserver(self, name: IAPHelper.IAPHelperPurchaseNotification, object: nil)
  }
  
  // MARK: - Actions
  
  @IBAction func tapBackButton(sender: UIBarButtonItem) {
    
    if settings.maxNumberFiles < numberAssetFiles {
      
      let alert = UIAlertController(title: NSLocalizedString("Warning!", comment: "SettingVC Error-Title"), message: NSLocalizedString("Existing files will be deleted. Do you want to continue?", comment: "SettingVC Error-Message"), preferredStyle: .Alert)
      let agreeAction = UIAlertAction(title: NSLocalizedString("OK", comment: "SettingVC Error-OK"), style: .Default) { (action: UIAlertAction!) -> Void in
        //print("OK")
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
          self.delegate?.saveSettings()
          self.dismissViewControllerAnimated(false, completion: nil)
        })
      }
      let cancelAction = UIAlertAction(title: NSLocalizedString("NO", comment: "SettingVC Error-NO"), style: .Default) { (action: UIAlertAction!) -> Void in
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
          self.settings.maxNumberFiles = self.oldSettingNumberFiles
          self.maxNumberFilesLabel.text = "\(self.oldSettingNumberFiles)"
          self.maxNumberFilesSlider.value = Float(self.oldSettingNumberFiles)
        })        
      }
      
      alert.addAction(agreeAction)
      alert.addAction(cancelAction)
      presentViewController(alert, animated: true, completion: nil)
    } else {
      self.delegate?.saveSettings()
      self.dismissViewControllerAnimated(true, completion: nil)
    }

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
  
  @IBAction func selectTextOnVideo(sender: UISwitch) {
    settings.textOnVideo = sender.on
    tableView.reloadData()
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
  
  @IBAction func changeLogo(sender: UIButton) {
    // print("Logo")
    guard let changeLogoProduct = changeLogoProduct else { return }
    IAPHelper.iapHelper.buyProduct(changeLogoProduct)
  }
  
  @IBAction func removeAds(sender: UIButton) {
    // print("Ads")
    guard let removeAdProduct = removeAdProduct else { return }
    IAPHelper.iapHelper.buyProduct(removeAdProduct)
  }
  
  @IBAction func restorePurchases(sender: UIButton) {
    // print("Restore")
    IAPHelper.iapHelper.restorePurchases()
  }
  
  @IBAction func setDefaultSettings(sender: AnyObject) {
    let new = Settings()
    
    settings.qualityMode = new.qualityMode
    settings.typeCamera = new.typeCamera
    settings.autofocusing = new.autofocusing
    settings.minIntervalLocations = new.minIntervalLocations
    settings.maxRecordingTime = new.maxRecordingTime
    settings.maxNumberFiles = new.maxNumberFiles
    settings.textOnVideo = new.textOnVideo

    setAllControls()
    tableView.reloadData()
  }
  
  func setAllControls() {
    qualityModeSegment.selectedSegmentIndex = settings.qualityMode.rawValue
    typeCameraSegment.selectedSegmentIndex = settings.typeCamera.rawValue
    autofocusingSwitch.on = settings.autofocusing
    minIntervalSlider.value = Float(settings.minIntervalLocations)
    typeSpeedSegment.selectedSegmentIndex = settings.typeSpeed.rawValue
    maxRecordingTimeSlider.value = Float(settings.maxRecordingTime)
    maxNumberFilesSlider.value = Float(settings.maxNumberFiles)
    logotypeTextField.text = settings.logotype
    textOnVideoSwitch.on = settings.textOnVideo
    
    minIntervalLabel.text = String(format: NSLocalizedString("%d m", comment: "SettingsVC Format for minIntervalLabel"), settings.minIntervalLocations)
    maxRecordingTimeLabel.text = String(format: NSLocalizedString("%d min", comment: "SettingsVC Format for maxRecordingTimeLabel"), settings.maxRecordingTime)
    maxNumberFilesLabel.text = "\(settings.maxNumberFiles)"
  }
  
  func requestIAPProducts() {
    
    IAPHelper.iapHelper.requestProducts {
      products in
      guard let products = products else { return }
      
      if !IAPHelper.iapHelper.setRemoveAd {
        self.removeAdProduct = products.filter {
          $0.productIdentifier == RecPurchase.RemoveAds.productId
        }.first
      }
      
      if self.removeAdProduct != .None {
        self.removeAdsButton.enabled = true
      }
      
      var changeLogoId = ""
      
      if self.settings.odometerMeters >= self.logo5000distance {
        changeLogoId = RecPurchase.ChangeLogo5000.productId
      } else if self.settings.odometerMeters >= self.logo1000distance {
        changeLogoId = RecPurchase.ChangeLogo1000.productId
      } else {
        changeLogoId = RecPurchase.ChangeLogo.productId
      }
      
      if !IAPHelper.iapHelper.setChangeLogo {
        self.changeLogoProduct = products.filter {
          $0.productIdentifier == changeLogoId
          }.first
      }
      
      if self.changeLogoProduct != .None {
        self.changeLogoButton.enabled = true
      }
      
      // print("AdRemoval Product: \(self.removeAdProduct?.productIdentifier) \n ChangeLogo Product: \(self.changeLogoProduct?.productIdentifier)")
    }
    
  }
  
  func handlePurchaseNotification(notification: NSNotification) {
    // print("handlePurchaseNotification")
    if let productID = notification.object as? String {
      
//      if productID == RecPurchase.RemoveAds.productId {
//        print("Bought: \(productID)")
//      } else if productID == RecPurchase.ChangeLogo.productId {
//        print("Bought: \(productID)")
//      } else if productID == RecPurchase.ChangeLogo1000.productId {
//        print("Bought: \(productID)")
//      } else if productID == RecPurchase.ChangeLogo5000.productId {
//        print("Bought: \(productID)")
//      }
      
      
      if productID == RecPurchase.RemoveAds.productId {
        IAPHelper.iapHelper.setRemoveAd = true
        IAPHelper.iapHelper.saveSettings(IAPHelper.RemoveAdKey)
        removeAdsButton.enabled = false
      } else if productID == RecPurchase.ChangeLogo.productId || productID == RecPurchase.ChangeLogo1000.productId || productID == RecPurchase.ChangeLogo5000.productId {
        IAPHelper.iapHelper.setChangeLogo = true
        IAPHelper.iapHelper.saveSettings(IAPHelper.ChangeLogoKey)
        changeLogoButton.enabled = false
      } else {
        print("No such product")
      }
      checkStateRestoreButton()
    }
  }
  
  func checkStateRestoreButton() {
    
    restorePurchasesButton.enabled = !(IAPHelper.iapHelper.setChangeLogo && IAPHelper.iapHelper.setRemoveAd)
  
  }
  
  
  override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    if section == 0 {
      if settings.textOnVideo {
        return 5
      } else {
        return 4
      }
    } else if section == 1 {
      return 3
    } else if section == 2 {
      return 2
    } else if section == 3 {
      return 3
    } else if section == 4 {
      return 1
    } else {
      return 0
    }
  }
  
}

extension SettingsViewController: UITextFieldDelegate {
  func textFieldShouldReturn(textField: UITextField) -> Bool {
    settings.logotype = textField.text!
    textField.resignFirstResponder()
    return true
  }
  
  func textFieldShouldBeginEditing(textField: UITextField) -> Bool {
    if !IAPHelper.iapHelper.setChangeLogo {
      guard let changeLogoProduct = changeLogoProduct else { return false }
      IAPHelper.iapHelper.buyProduct(changeLogoProduct)
    }
    
    return IAPHelper.iapHelper.setChangeLogo
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

