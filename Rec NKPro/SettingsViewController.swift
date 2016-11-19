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
  
  weak var delegate: SettingsControllerDelegate?
  var settings: Settings!
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
    
    fullVersionButton.isEnabled = false

    logotypeTextField.delegate = self
    
    setAllControls()
    
    //print("Distance: \(settings.odometerMeters)")
    //settings.odometerMeters = 1_000_001
    
    fullVersionButton.isEnabled = IAPHelper.iapHelper.isSelling
    let title = NSLocalizedString("Full Version - ", comment: "SettingsVC: Full Version") + IAPHelper.iapHelper.price
    fullVersionButton.setTitle(title, for: UIControlState())
    
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
      sender.value = 1.0
      if !alertMaxTime {
        alertMaxTime = true
        let message = NSLocalizedString("For running this function you need to buy Full Version\n", comment: "SettingVC Error-Message") + IAPHelper.iapHelper.price
        let alert = UIAlertController(title: NSLocalizedString("Message", comment: "SettingVC Error-Title"), message: message, preferredStyle: .alert)
        
        let buyAction = UIAlertAction(title: NSLocalizedString("Buy", comment: "SettingVC Error-Buy"), style: .default) { (action: UIAlertAction!) -> Void in
          self.alertMaxVideo = false
          guard let fullVersionProduct = IAPHelper.iapHelper.fullVersionProduct else { return }
          IAPHelper.iapHelper.buyProduct(fullVersionProduct)
        }
        
        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: "SettingVC Error-Cancel"), style: .cancel) { (action: UIAlertAction!) -> Void in
          self.alertMaxTime = false
        }
        
        if IAPHelper.iapHelper.isSelling {
          alert.addAction(buyAction)
        }
        alert.addAction(cancelAction)
        present(alert, animated: true, completion: nil)
      }

    } else {
      let value = Int(sender.value)
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
        let message = NSLocalizedString("For running this function you need to buy Full Version\n", comment: "SettingVC Error-Message") + IAPHelper.iapHelper.price
        let alert = UIAlertController(title: NSLocalizedString("Message", comment: "SettingVC Error-Title"), message: message, preferredStyle: .alert)
        
        let buyAction = UIAlertAction(title: NSLocalizedString("Buy", comment: "SettingVC Error-Buy"), style: .default) { (action: UIAlertAction!) -> Void in
          self.alertMaxVideo = false
          guard let fullVersionProduct = IAPHelper.iapHelper.fullVersionProduct else { return }
          IAPHelper.iapHelper.buyProduct(fullVersionProduct)
        }
        
        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: "SettingVC Error-Cancel"), style: .cancel) { (action: UIAlertAction!) -> Void in
          self.alertMaxVideo = false
        }
        if IAPHelper.iapHelper.isSelling {
          alert.addAction(buyAction)
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
    guard let fullVersionProduct = IAPHelper.iapHelper.fullVersionProduct else { return }
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
    settings.isMicOn = new.isMicOn

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

