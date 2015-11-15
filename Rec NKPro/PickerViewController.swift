//
//  PickerViewController.swift
//  FixDrive
//
//  Created by NK on 08.11.15.
//  Copyright © 2015 Nikolay Kolesnikov. All rights reserved.
//

import UIKit

class PickerViewController: UIImagePickerController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
  
  override func prefersStatusBarHidden() -> Bool {
    
    return true
  }
  
  override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
    return .All
  }

}
