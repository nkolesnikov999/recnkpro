//
//  PictureViewController.swift
//  Rec NKPro
//
//  Created by NK on 07.04.16.
//  Copyright © 2016 Nikolay Kolesnikov. All rights reserved.
//

import UIKit

class PictureViewController: UIViewController {
  
  @IBOutlet weak var dateLabel: UILabel!
  @IBOutlet weak var addresLabel: UILabel!
  @IBOutlet weak var pictureView: UIImageView!
  @IBOutlet weak var beforeLabel: UILabel!
  @IBOutlet weak var afterLabel: UILabel!
  
  var pictureIndex: Int!
  var picture: Picture!
  var image: UIImage!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    dateLabel.text = " "
    addresLabel.text = " "
    
    if let picture = self.picture {
      let dateFormater = DateFormatter()
      dateFormater.dateFormat = "yyyy/MM/dd HH:mm:ss"
      dateLabel.text = dateFormater.string(from: picture.date as Date)
      addresLabel.text = picture.address
      //print("Address: \(picture.address)")
      image = picture.loadImage()
    }
    
    if pictureIndex == 0 {
      beforeLabel.isHidden = true
    }
    
    let count = PicturesList.pList.pictures.count
    if pictureIndex == count - 1 || count == 0 {
      afterLabel.isHidden = true
    }
    
    // Do any additional setup after loading the view.
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    if let image = self.image {
      pictureView.image = image.thumbnailOfSize(CGSize(width: pictureView.bounds.width, height: pictureView.bounds.height))
    } else {
      pictureView.image = UIImage(named: "Placeholder")
    }
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  @IBAction func openZoomingController(_ sender: AnyObject) {
    if image != nil {
      self.performSegue(withIdentifier: "zoomSegue", sender: nil)
    }
  }
  
   // MARK: - Navigation
  
   override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if segue.identifier == "zoomSegue" {
      if let destVC = segue.destination as? ZoomedPhotoViewController {
        destVC.image = image
      }
    }
  }

  
}
