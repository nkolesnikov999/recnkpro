//
//  VoiceControlViewController.swift
//  Rec NKPro
//
//  Created by NK on 19.11.16.
//  Copyright © 2016 Nikolay Kolesnikov. All rights reserved.
//

import UIKit

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
    
  }
  
  override var prefersStatusBarHidden : Bool {
    
    return true
  }
  
  @IBAction func resetAction(_ sender: Any) {
    
  }
}

extension VoiceControlViewController: UITextFieldDelegate {
  func textFieldShouldReturn(_ textField: UITextField) -> Bool {
    textField.resignFirstResponder()
    return true
  }
}
