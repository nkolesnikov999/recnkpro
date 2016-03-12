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
  
  private var fullVersionProduct: SKProduct?
  
  weak var delegate: SettingsControllerDelegate?
  var settings: Settings!
  var price = ""
  var alertMaxVideo = false
  var alertMaxPictures = false
  
  var numberAssetFiles = 0
  var numberPictureAsset = 0
  var oldSettingNumberVideo = 0
  var oldSettingNumberPicture = 0
  
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
  @IBOutlet weak var maxNumberPicturesLabel: UILabel!
  @IBOutlet weak var maxNumberPicturesSlider: UISlider!
  @IBOutlet weak var intervalPicturesLabel: UILabel!
  @IBOutlet weak var intervalPicturesSlider: UISlider!
  @IBOutlet weak var logotypeTextField: UITextField!
  @IBOutlet weak var fullVersionButton: UIButton!
  @IBOutlet weak var restorePurchasesButton: UIButton!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    let modelName = UIDevice.currentDevice().modelName
    
    if modelName == "iPhone 4s" {
      //qualityModeSegment.removeSegmentAtIndex(2, animated: false)
    }
    
    fullVersionButton.enabled = false

    logotypeTextField.delegate = self
    
    setAllControls()
    
    //print("Distance: \(settings.odometerMeters)")
    //settings.odometerMeters = 1_000_001
    
    requestIAPProducts()
    NSNotificationCenter.defaultCenter().addObserver(self, selector: "handlePurchaseNotification:", name: IAPHelper.IAPHelperPurchaseNotification, object: nil)
    checkStateRestoreButton()
    
    oldSettingNumberVideo = settings.maxNumberVideo
    oldSettingNumberPicture = settings.maxNumberPictures
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
    
    if settings.maxNumberVideo < numberAssetFiles  && IAPHelper.iapHelper.setFullVersion {
      
      let alert = UIAlertController(title: NSLocalizedString("Warning!", comment: "SettingVC Error-Title"), message: NSLocalizedString("Existing video will be deleted. Do you want to continue?", comment: "SettingVC Error-Message"), preferredStyle: .Alert)
      let agreeAction = UIAlertAction(title: NSLocalizedString("OK", comment: "SettingVC Error-OK"), style: .Default) { (action: UIAlertAction!) -> Void in
        //print("OK")
        defer {
          dispatch_async(dispatch_get_main_queue(), { () -> Void in
            self.delegate?.saveSettings()
            self.dismissViewControllerAnimated(false, completion: nil)
          })
        }
      }
      let cancelAction = UIAlertAction(title: NSLocalizedString("NO", comment: "SettingVC Error-NO"), style: .Default) { (action: UIAlertAction!) -> Void in
        defer {
          dispatch_async(dispatch_get_main_queue(), { () -> Void in
            self.settings.maxNumberVideo = self.oldSettingNumberVideo
            self.maxNumberFilesLabel.text = "\(self.oldSettingNumberVideo)"
            self.maxNumberFilesSlider.value = Float(self.oldSettingNumberVideo)
          })
        }
      }
      
      alert.addAction(agreeAction)
      alert.addAction(cancelAction)
      presentViewController(alert, animated: true, completion: nil)
    } else if settings.maxNumberPictures < numberPictureAsset  && IAPHelper.iapHelper.setFullVersion {
      
      let alert = UIAlertController(title: NSLocalizedString("Warning!", comment: "SettingVC Error-Title"), message: NSLocalizedString("Existing pictures will be deleted. Do you want to continue?", comment: "SettingVC Error-Message"), preferredStyle: .Alert)
      let agreeAction = UIAlertAction(title: NSLocalizedString("OK", comment: "SettingVC Error-OK"), style: .Default) { (action: UIAlertAction!) -> Void in
        //print("OK")
        defer {
          dispatch_async(dispatch_get_main_queue(), { () -> Void in
            self.delegate?.saveSettings()
            self.dismissViewControllerAnimated(false, completion: nil)
          })
        }
      }
      let cancelAction = UIAlertAction(title: NSLocalizedString("NO", comment: "SettingVC Error-NO"), style: .Default) { (action: UIAlertAction!) -> Void in
        defer {
          dispatch_async(dispatch_get_main_queue(), { () -> Void in
            self.settings.maxNumberPictures = self.oldSettingNumberPicture 
            self.maxNumberPicturesLabel.text = "\(self.oldSettingNumberPicture)"
            self.maxNumberPicturesSlider.value = Float(self.oldSettingNumberPicture)
          })
        }
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
    
    if settings.typeCamera == .Back {
      settings.backQualityMode = QualityMode(rawValue:  sender.selectedSegmentIndex)!
    } else {
      settings.frontQualityMode = QualityMode(rawValue:  sender.selectedSegmentIndex)!
    }

  }
  
  @IBAction func selectTypeCamera(sender: UISegmentedControl) {
    settings.typeCamera = TypeCamera(rawValue: sender.selectedSegmentIndex)!
    
    if settings.typeCamera == .Back {
      qualityModeSegment.selectedSegmentIndex = settings.backQualityMode.rawValue
    } else {
      qualityModeSegment.selectedSegmentIndex = settings.frontQualityMode.rawValue
    }
    
  }
  
  @IBAction func selectAutofocusing(sender: UISwitch) {
    settings.autofocusing = sender.on
  }
  
  @IBAction func selectTextOnVideo(sender: UISwitch) {
    settings.textOnVideo = sender.on
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
    //print("valueChange")
    
    if Int(sender.value) > settings.maxNumberVideo && !IAPHelper.iapHelper.setFullVersion {       sender.value = Float(settings.maxNumberVideo)
      
      if !alertMaxVideo {
        alertMaxVideo = true
        let alert = UIAlertController(title: NSLocalizedString("Message", comment: "SettingVC Error-Title"), message: NSLocalizedString("For running this function you need to buy Full Version", comment: "SettingVC Error-Message"), preferredStyle: .Alert)
        
        let cancelAction = UIAlertAction(title: NSLocalizedString("OK", comment: "SettingVC Error-OK"), style: .Default) { (action: UIAlertAction!) -> Void in
          self.alertMaxVideo = false
        }
        
        alert.addAction(cancelAction)
        presentViewController(alert, animated: true, completion: nil)
      }

    } else {
      let value = Int(sender.value)
      sender.value = Float(value)
      maxNumberFilesLabel.text = "\(value)"
      settings.maxNumberVideo = value
    }
    
  }
  
  @IBAction func setMaxNumberPictures(sender: UISlider) {
    let partValue = sender.value/10
    let value = Int(partValue) * 10
    sender.value = Float(value)
    if Int(sender.value) > settings.maxNumberPictures && !IAPHelper.iapHelper.setFullVersion {
      sender.value = Float(settings.maxNumberPictures)
      
      if !alertMaxPictures {
        alertMaxPictures = true
        let alert = UIAlertController(title: NSLocalizedString("Message", comment: "SettingVC Error-Title"), message: NSLocalizedString("For running this function you need to buy Full Version", comment: "SettingVC Error-Message"), preferredStyle: .Alert)
        
        let cancelAction = UIAlertAction(title: NSLocalizedString("OK", comment: "SettingVC Error-OK"), style: .Default) { (action: UIAlertAction!) -> Void in
          self.alertMaxPictures = false
        }
        
        alert.addAction(cancelAction)
        presentViewController(alert, animated: true, completion: nil)
      }
      
    } else {
      let value = Int(sender.value)
      sender.value = Float(value)
      maxNumberPicturesLabel.text = "\(value)"
      settings.maxNumberPictures = value
    }

  }
  
  @IBAction func setIntervalPictures(sender: UISlider) {
    let partValue = sender.value/5
    let value = Int(partValue) * 5
    sender.value = Float(value)
    intervalPicturesLabel.text =  String(format: NSLocalizedString("%d s", comment: "SettingsVC Format for intervalPicturesLabel"), value)
    
    settings.intervalPictures = value
  }
  
  @IBAction func resetOdometer(sender: AnyObject) {
    settings.odometerMeters = 0
  }
  
  @IBAction func buyFullVersion(sender: UIButton) {
    // print("Logo")
    guard let fullVersionProduct = fullVersionProduct else { return }
    IAPHelper.iapHelper.buyProduct(fullVersionProduct)
  }

  
  @IBAction func restorePurchases(sender: UIButton) {
    // print("Restore")
    IAPHelper.iapHelper.restorePurchases()
  }
  
  @IBAction func setDefaultSettings(sender: AnyObject) {
    let new = Settings()
    
    settings.backQualityMode = new.backQualityMode
    settings.frontQualityMode = new.frontQualityMode
    settings.typeCamera = new.typeCamera
    settings.autofocusing = new.autofocusing
    settings.minIntervalLocations = new.minIntervalLocations
    settings.maxRecordingTime = new.maxRecordingTime
    settings.maxNumberVideo = new.maxNumberVideo
    settings.maxNumberPictures = new.maxNumberPictures
    settings.intervalPictures = new.intervalPictures
    settings.textOnVideo = new.textOnVideo

    setAllControls()
    tableView.reloadData()
  }
  
  func setAllControls() {

    typeCameraSegment.selectedSegmentIndex = settings.typeCamera.rawValue
    
    if settings.typeCamera == .Back {
      qualityModeSegment.selectedSegmentIndex = settings.backQualityMode.rawValue
    } else {
      qualityModeSegment.selectedSegmentIndex = settings.frontQualityMode.rawValue
    }
    
    autofocusingSwitch.on = settings.autofocusing
    minIntervalSlider.value = Float(settings.minIntervalLocations)
    typeSpeedSegment.selectedSegmentIndex = settings.typeSpeed.rawValue
    maxRecordingTimeSlider.value = Float(settings.maxRecordingTime)
    maxNumberFilesSlider.value = Float(settings.maxNumberVideo)
    maxNumberPicturesSlider.value = Float(settings.maxNumberPictures)
    intervalPicturesSlider.value = Float(settings.intervalPictures)
    logotypeTextField.text = settings.logotype
    textOnVideoSwitch.on = settings.textOnVideo
    
    minIntervalLabel.text = String(format: NSLocalizedString("%d m", comment: "SettingsVC Format for minIntervalLabel"), settings.minIntervalLocations)
    maxRecordingTimeLabel.text = String(format: NSLocalizedString("%d min", comment: "SettingsVC Format for maxRecordingTimeLabel"), settings.maxRecordingTime)
    maxNumberFilesLabel.text = "\(settings.maxNumberVideo)"
    maxNumberPicturesLabel.text = "\(settings.maxNumberPictures)"
    intervalPicturesLabel.text = String(format: NSLocalizedString("%d s", comment: "SettingsVC Format for intervalPicturesLabel"), settings.intervalPictures)
  }
  
  func requestIAPProducts() {
    
    IAPHelper.iapHelper.requestProducts {
      products in
      guard let products = products else { return }
      
      if !IAPHelper.iapHelper.setFullVersion {
        self.fullVersionProduct = products.filter {
          $0.productIdentifier == RecPurchase.FullVersion.productId
        }.first
      }
      
      if self.fullVersionProduct != .None {
        self.fullVersionButton.enabled = true
        
        let priceFormatter = NSNumberFormatter()
        priceFormatter.numberStyle = .CurrencyStyle
        priceFormatter.locale = self.fullVersionProduct?.priceLocale
        
        if let price = self.fullVersionProduct?.price {
          if let strPrice = priceFormatter.stringFromNumber(price) {
            self.price = strPrice
          }
        }
        
        let title = NSLocalizedString("Full Version - ", comment: "SettingsVC: Full Version") + self.price
        self.fullVersionButton.setTitle(title, forState: .Normal)
      }
      
      
    
      print("FullVersion Product: \(self.fullVersionProduct?.productIdentifier), price: \(self.price)")
    }
    
  }
  
  func handlePurchaseNotification(notification: NSNotification) {
    // print("handlePurchaseNotification")
    if let productID = notification.object as? String {
      
        print("Bought: \(productID)")
      
      if productID == RecPurchase.FullVersion.productId {
        IAPHelper.iapHelper.setFullVersion = true
        IAPHelper.iapHelper.saveSettings(IAPHelper.FullVersionKey)
        fullVersionButton.enabled = false
      } else {
        print("No such product")
      }
      checkStateRestoreButton()
    }
  }
  
  func checkStateRestoreButton() {
    
    restorePurchasesButton.enabled = !(IAPHelper.iapHelper.setFullVersion)
  
  }
  
}

extension SettingsViewController: UITextFieldDelegate {
  func textFieldShouldReturn(textField: UITextField) -> Bool {
    settings.logotype = textField.text!
    textField.resignFirstResponder()
    return true
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

