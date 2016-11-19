//
//  VoiceControlViewController.swift
//  Rec NKPro
//
//  Created by NK on 19.11.16.
//  Copyright © 2016 Nikolay Kolesnikov. All rights reserved.
//

import UIKit

let recordVideoVoiceString = NSLocalizedString("record", comment: "VoiceVC-Record")
let stopVideoVoiceString = NSLocalizedString("stop", comment: "VoiceVC-Stop")
let lockVideoVoiceString = NSLocalizedString("lock", comment: "VoiceVC-Lock")
let unlockVideoVoiceString = NSLocalizedString("unlock", comment: "VoiceVC-Unlock")
let changeCameraVoiceString = NSLocalizedString("camera", comment: "VoiceVC-Camera")
let takePictureVoiceString = NSLocalizedString("picture", comment: "VoiceVC-Picture")
let autoPictureVoiceString = NSLocalizedString("auto", comment: "VoiceVC-Auto")
let addressVoiceString = NSLocalizedString("address", comment: "VoiceVC-Address")
let speedVoiceString = NSLocalizedString("speed", comment: "VoiceVC-Speed")
let answerVoiceString = NSLocalizedString("ok", comment: "VoiceVC-Ok")

class VoiceControlViewController: UITableViewController {
  
  @IBOutlet weak var recordVideoTextField: UITextField!
  @IBOutlet weak var stopRecordTextField: UITextField!
  @IBOutlet weak var lockVideoTextField: UITextField!
  @IBOutlet weak var unlockVideoTextField: UITextField!
  @IBOutlet weak var changeCameraTextField: UITextField!
  @IBOutlet weak var takePictureTextField: UITextField!
  @IBOutlet weak var autoPictureTextField: UITextField!
  @IBOutlet weak var addressTextField: UITextField!
  @IBOutlet weak var speedTextField: UITextField!
  @IBOutlet weak var answerTextField: UITextField!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    recordVideoTextField.delegate = self
    stopRecordTextField.delegate = self
    lockVideoTextField.delegate = self
    unlockVideoTextField.delegate = self
    changeCameraTextField.delegate = self
    takePictureTextField.delegate = self
    autoPictureTextField.delegate = self
    addressTextField.delegate = self
    speedTextField.delegate = self
    answerTextField.delegate = self
    
    loadCommands()
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    saveCommands()
  }
  
  override var prefersStatusBarHidden : Bool {
    
    return true
  }
  
  @IBAction func resetAction(_ sender: Any) {
    recordVideoTextField.text = recordVideoVoiceString
    stopRecordTextField.text = stopVideoVoiceString
    lockVideoTextField.text = lockVideoVoiceString
    unlockVideoTextField.text = unlockVideoVoiceString
    changeCameraTextField.text = changeCameraVoiceString
    takePictureTextField.text = takePictureVoiceString
    autoPictureTextField.text = autoPictureVoiceString
    addressTextField.text = addressVoiceString
    speedTextField.text = speedVoiceString
    answerTextField.text = answerVoiceString
  }
  
  func loadCommands() {
    if let storedRecord = UserDefaults.standard.string(forKey: RecordVideoVoiceKey) {
      recordVideoTextField.text = storedRecord
    }
    
    if let storedStop = UserDefaults.standard.string(forKey: StopVideoVoiceKey) {
      stopRecordTextField.text = storedStop
    }
    
    if let storedLock = UserDefaults.standard.string(forKey: LockVideoVoiceKey) {
      lockVideoTextField.text = storedLock
    }
    
    if let storedUnlock = UserDefaults.standard.string(forKey: UnlockVideoVoiceKey) {
      unlockVideoTextField.text = storedUnlock
    }
    
    if let storedCamera = UserDefaults.standard.string(forKey: ChangeCameraVoiceKey) {
      changeCameraTextField.text = storedCamera
    }
    
    if let storedPicture = UserDefaults.standard.string(forKey: TakePictureVoiceKey) {
      takePictureTextField.text = storedPicture
    }
    
    if let storedAuto = UserDefaults.standard.string(forKey: AutoPictureVoiceKey) {
      autoPictureTextField.text = storedAuto
    }
    
    if let storedAddress = UserDefaults.standard.string(forKey: AddressVoiceKey) {
      addressTextField.text = storedAddress
    }
    
    if let storedSpeed = UserDefaults.standard.string(forKey: SpeedVoiceKey) {
      speedTextField.text = storedSpeed
    }
    
    if let storedAnswer = UserDefaults.standard.string(forKey: AnswerVoiceKey) {
      answerTextField.text = storedAnswer
    }
  }
  
  func saveCommands() {
    
      UserDefaults.standard.set(recordVideoTextField.text, forKey: RecordVideoVoiceKey)
      UserDefaults.standard.set(stopRecordTextField.text, forKey: StopVideoVoiceKey)
      UserDefaults.standard.set(lockVideoTextField.text, forKey: LockVideoVoiceKey)
      UserDefaults.standard.set(unlockVideoTextField.text, forKey: UnlockVideoVoiceKey)
      UserDefaults.standard.set(changeCameraTextField.text, forKey: ChangeCameraVoiceKey)
      UserDefaults.standard.set(takePictureTextField.text, forKey: TakePictureVoiceKey)
      UserDefaults.standard.set(autoPictureTextField.text, forKey: AutoPictureVoiceKey)
      UserDefaults.standard.set(addressTextField.text, forKey: AddressVoiceKey)
      UserDefaults.standard.set(speedTextField.text, forKey: SpeedVoiceKey)
      UserDefaults.standard.set(answerTextField.text, forKey: AnswerVoiceKey)
    
    UserDefaults.standard.synchronize()
  }

}

extension VoiceControlViewController: UITextFieldDelegate {
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    textField.resignFirstResponder()
    return true
  }
}
