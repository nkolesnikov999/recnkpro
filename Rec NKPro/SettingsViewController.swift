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
  
  fileprivate var fullVersionProduct: SKProduct?
  
  weak var delegate: SettingsControllerDelegate?
  var settings: Settings!
  var price = ""
  var alertMaxVideo = false
  var alertMaxTime = false
  
  var numberAssetFiles = 0
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
  @IBOutlet weak var intervalPicturesLabel: UILabel!
  @IBOutlet weak var intervalPicturesSlider: UISlider!
  @IBOutlet weak var logotypeTextField: UITextField!
  @IBOutlet weak var fullVersionButton: UIButton!
  @IBOutlet weak var restorePurchasesButton: UIButton!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    let modelName = UIDevice.current.modelName
    
    if modelName == "iPhone 4s" {
      //qualityModeSegment.removeSegmentAtIndex(2, animated: false)
    }
    
    fullVersionButton.isEnabled = false

    logotypeTextField.delegate = self
    
    setAllControls()
    
    //print("Distance: \(settings.odometerMeters)")
    //settings.odometerMeters = 1_000_001
    
    requestIAPProducts()
    NotificationCenter.default.addObserver(self, selector: #selector(SettingsViewController.handlePurchaseNotification(_:)), name: NSNotification.Name(rawValue: IAPHelper.IAPHelperPurchaseNotification), object: nil)
    checkStateRestoreButton()
    
    oldSettingNumberVideo = settings.maxNumberVideo
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  override var prefersStatusBarHidden : Bool {
    
    return true
  }
  
  deinit {
    NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: IAPHelper.IAPHelperPurchaseNotification), object: nil)
  }
  
  // MARK: - Actions
  
  @IBAction func tapBackButton(_ sender: UIBarButtonItem) {
    
    if settings.maxNumberVideo < numberAssetFiles  && IAPHelper.iapHelper.setFullVersion {
      
      let alert = UIAlertController(title: NSLocalizedString("Warning!", comment: "SettingVC Error-Title"), message: NSLocalizedString("Existing video will be deleted. Do you want to continue?", comment: "SettingVC Error-Message"), preferredStyle: .alert)
      let agreeAction = UIAlertAction(title: NSLocalizedString("OK", comment: "SettingVC Error-OK"), style: .default) { (action: UIAlertAction!) -> Void in
        //print("OK")
        defer {
          DispatchQueue.main.async(execute: { () -> Void in
            self.delegate?.saveSettings()
            self.dismiss(animated: false, completion: nil)
          })
        }
      }
      let cancelAction = UIAlertAction(title: NSLocalizedString("NO", comment: "SettingVC Error-NO"), style: .default) { (action: UIAlertAction!) -> Void in
        defer {
          DispatchQueue.main.async(execute: { () -> Void in
            self.settings.maxNumberVideo = self.oldSettingNumberVideo
            self.maxNumberFilesLabel.text = "\(self.oldSettingNumberVideo)"
            self.maxNumberFilesSlider.value = Float(self.oldSettingNumberVideo)
          })
        }
      }
      
      alert.addAction(agreeAction)
      alert.addAction(cancelAction)
      present(alert, animated: true, completion: nil)
    } else {
      if settings.maxRecordingTime > 5 && !IAPHelper.iapHelper.setFullVersion {
        settings.maxRecordingTime = 5
      }
      self.delegate?.saveSettings()
      self.dismiss(animated: true, completion: nil)
    }

  }

  @IBAction func selectQualityMode(_ sender: UISegmentedControl) {
    
    if settings.typeCamera == .back {
      settings.backQualityMode = QualityMode(rawValue:  sender.selectedSegmentIndex)!
    } else {
      settings.frontQualityMode = QualityMode(rawValue:  sender.selectedSegmentIndex)!
    }

  }
  
  @IBAction func selectTypeCamera(_ sender: UISegmentedControl) {
    settings.typeCamera = TypeCamera(rawValue: sender.selectedSegmentIndex)!
    
    if settings.typeCamera == .back {
      qualityModeSegment.selectedSegmentIndex = settings.backQualityMode.rawValue
    } else {
      qualityModeSegment.selectedSegmentIndex = settings.frontQualityMode.rawValue
    }
    
  }
  
  @IBAction func selectAutofocusing(_ sender: UISwitch) {
    settings.autofocusing = sender.isOn
  }
  
  @IBAction func selectTextOnVideo(_ sender: UISwitch) {
    settings.textOnVideo = sender.isOn
  }
  
  @IBAction func setMinInterval(_ sender: UISlider) {
    let partValue = sender.value/10
    let value = Int(partValue) * 10
    sender.value = Float(value)
    minIntervalLabel.text = String(format: NSLocalizedString("%d m", comment: "SettingsVC Format for minIntervalLabel"), value)
    settings.minIntervalLocations = value
  }
  
  @IBAction func setTypeSpeed(_ sender: UISegmentedControl) {
    settings.typeSpeed = TypeSpeed(rawValue: sender.selectedSegmentIndex)!
  }
  
  @IBAction func setMaxRecordingTime(_ sender: UISlider) {
    
    if !IAPHelper.iapHelper.setFullVersion {
      sender.value = 5.0
      if !alertMaxTime {
        alertMaxTime = true
        let alert = UIAlertController(title: NSLocalizedString("Message", comment: "SettingVC Error-Title"), message: NSLocalizedString("For running this function you need to buy Full Version", comment: "SettingVC Error-Message"), preferredStyle: .alert)
        
        let cancelAction = UIAlertAction(title: NSLocalizedString("OK", comment: "SettingVC Error-OK"), style: .default) { (action: UIAlertAction!) -> Void in
          self.alertMaxTime = false
        }
        alert.addAction(cancelAction)
        present(alert, animated: true, completion: nil)
      }

    } else {
      let partValue = sender.value/5
      let value = Int(partValue) * 5
      sender.value = Float(value)
      maxRecordingTimeLabel.text =  String(format: NSLocalizedString("%d min", comment: "SettingsVC Format for maxRecordingTimeLabel"), value)
      settings.maxRecordingTime = value
    }
  }
  
  @IBAction func setMaxNumberFiles(_ sender: UISlider) {
    //print("valueChange")
    
    if Int(sender.value) > settings.maxNumberVideo && !IAPHelper.iapHelper.setFullVersion {
      sender.value = Float(settings.maxNumberVideo)
      
      if !alertMaxVideo {
        alertMaxVideo = true
        let alert = UIAlertController(title: NSLocalizedString("Message", comment: "SettingVC Error-Title"), message: NSLocalizedString("For running this function you need to buy Full Version", comment: "SettingVC Error-Message"), preferredStyle: .alert)
        
        let cancelAction = UIAlertAction(title: NSLocalizedString("OK", comment: "SettingVC Error-OK"), style: .default) { (action: UIAlertAction!) -> Void in
          self.alertMaxVideo = false
        }
        
        alert.addAction(cancelAction)
        present(alert, animated: true, completion: nil)
      }

    } else {
      let value = Int(sender.value)
      sender.value = Float(value)
      maxNumberFilesLabel.text = "\(value)"
      settings.maxNumberVideo = value
    }
    
  }
  
  @IBAction func setIntervalPictures(_ sender: UISlider) {
    let partValue = sender.value/10
    let value = Int(partValue) * 10
    sender.value = Float(value)
    intervalPicturesLabel.text =  String(format: NSLocalizedString("%d s", comment: "SettingsVC Format for intervalPicturesLabel"), value)
    
    settings.intervalPictures = value
  }
  
  @IBAction func resetOdometer(_ sender: AnyObject) {
    settings.odometerMeters = 0
  }
  
  @IBAction func buyFullVersion(_ sender: UIButton) {
    // print("Logo")
    guard let fullVersionProduct = fullVersionProduct else { return }
    IAPHelper.iapHelper.buyProduct(fullVersionProduct)
  }

  
  @IBAction func restorePurchases(_ sender: UIButton) {
    // print("Restore")
    IAPHelper.iapHelper.restorePurchases()
  }
  
  @IBAction func setDefaultSettings(_ sender: AnyObject) {
    let new = Settings()
    
    settings.backQualityMode = new.backQualityMode
    settings.frontQualityMode = new.frontQualityMode
    settings.typeCamera = new.typeCamera
    settings.autofocusing = new.autofocusing
    settings.minIntervalLocations = new.minIntervalLocations
    settings.maxRecordingTime = new.maxRecordingTime
    settings.maxNumberVideo = new.maxNumberVideo
    settings.intervalPictures = new.intervalPictures
    settings.textOnVideo = new.textOnVideo

    setAllControls()
    tableView.reloadData()
  }
  
  func setAllControls() {

    typeCameraSegment.selectedSegmentIndex = settings.typeCamera.rawValue
    
    if settings.typeCamera == .back {
      qualityModeSegment.selectedSegmentIndex = settings.backQualityMode.rawValue
    } else {
      qualityModeSegment.selectedSegmentIndex = settings.frontQualityMode.rawValue
    }
    
    autofocusingSwitch.isOn = settings.autofocusing
    minIntervalSlider.value = Float(settings.minIntervalLocations)
    typeSpeedSegment.selectedSegmentIndex = settings.typeSpeed.rawValue
    maxRecordingTimeSlider.value = Float(settings.maxRecordingTime)
    maxNumberFilesSlider.value = Float(settings.maxNumberVideo)
    intervalPicturesSlider.value = Float(settings.intervalPictures)
    logotypeTextField.text = settings.logotype
    textOnVideoSwitch.isOn = settings.textOnVideo
    
    minIntervalLabel.text = String(format: NSLocalizedString("%d m", comment: "SettingsVC Format for minIntervalLabel"), settings.minIntervalLocations)
    maxRecordingTimeLabel.text = String(format: NSLocalizedString("%d min", comment: "SettingsVC Format for maxRecordingTimeLabel"), settings.maxRecordingTime)
    maxNumberFilesLabel.text = "\(settings.maxNumberVideo)"
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
      
      if self.fullVersionProduct != .none {
        self.fullVersionButton.isEnabled = true
        
        let priceFormatter = NumberFormatter()
        priceFormatter.numberStyle = .currency
        priceFormatter.locale = self.fullVersionProduct?.priceLocale
        
        if let price = self.fullVersionProduct?.price {
          if let strPrice = priceFormatter.string(from: price) {
            self.price = strPrice
          }
        }
        
        let title = NSLocalizedString("Full Version - ", comment: "SettingsVC: Full Version") + self.price
        self.fullVersionButton.setTitle(title, for: UIControlState())
      }
      
      
    
      print("FullVersion Product: \(self.fullVersionProduct?.productIdentifier), price: \(self.price)")
    }
    
  }
  
  func handlePurchaseNotification(_ notification: Notification) {
    // print("handlePurchaseNotification")
    if let productID = notification.object as? String {
      
        print("Bought: \(productID)")
      
      if productID == RecPurchase.FullVersion.productId {
        IAPHelper.iapHelper.setFullVersion = true
        IAPHelper.iapHelper.saveSettings(IAPHelper.FullVersionKey)
        fullVersionButton.isEnabled = false
      } else {
        print("No such product")
      }
      checkStateRestoreButton()
    }
  }
  
  func checkStateRestoreButton() {
    
    restorePurchasesButton.isEnabled = !(IAPHelper.iapHelper.setFullVersion)
  
  }
  
}

extension SettingsViewController: UITextFieldDelegate {
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
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
      guard let value = element.value as? Int8 , value != 0 else { return identifier }
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

