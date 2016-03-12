//
//  PicturesViewController.swift
//  Rec NKPro
//
//  Created by NK on 11.03.16.
//  Copyright © 2016 Nikolay Kolesnikov. All rights reserved.
//

import UIKit

class PicturesViewController: UIViewController {
  
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
  
  override func shouldAutorotate() -> Bool {
    return true
  }
  
  @IBAction func tapCamera(sender: UIBarButtonItem) {
    dismissViewControllerAnimated(true, completion: nil)
  }
  
}
