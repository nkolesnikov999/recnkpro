//
//  TabBarViewController.swift
//  Rec NKPro
//
//  Created by NK on 05.04.16.
//  Copyright © 2016 Nikolay Kolesnikov. All rights reserved.
//

import UIKit

class TabBarViewController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

  override var prefersStatusBarHidden : Bool {
    
    return true
  }

}
