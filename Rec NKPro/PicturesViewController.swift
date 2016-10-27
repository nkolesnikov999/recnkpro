//
//  PicturesViewController.swift
//  Rec NKPro
//
//  Created by NK on 11.03.16.
//  Copyright © 2016 Nikolay Kolesnikov. All rights reserved.
//

import UIKit
import Photos

class PicturesViewController: UITableViewController {
  
  enum AlertMessage: Int {
    case fullVersion = 0
    case photoSaved = 1
    case photoNoSaved = 2
  }

  var image: UIImage?
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // Do any additional setup after loading the view.
    navigationItem.rightBarButtonItem = editButtonItem
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    tableView.reloadData()
  }
  
  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    PicturesList.pList.savePictures()
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  override var prefersStatusBarHidden : Bool {
    
    return true
  }
  
  override var shouldAutorotate : Bool {
    return true
  }
  
  @IBAction func tapCamera(_ sender: UIBarButtonItem) {
    dismiss(animated: true, completion: nil)
  }
  
  func removeImage(_ picture: Picture) {
    
    let directory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
    let path = directory.appendingPathComponent(picture.title).path
    
    let fileManager = FileManager.default
    if fileManager.fileExists(atPath: path) {
      do {
        try fileManager.removeItem(atPath: path)
        //print("Image deleted")
      } catch {
        let nserror = error as NSError
        print("ERROR: PictureVC.removeFile - \(nserror.userInfo)")
      }
    }

  }
  
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if segue.identifier == "pictureSegue" {
      if let destVC = segue.destination as? ZoomedPhotoViewController {
        if let image = image {
          destVC.image = image
        }
      }
    }
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return PicturesList.pList.pictures.count
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "PictureCell", for: indexPath) as UITableViewCell
    let picture = PicturesList.pList.pictures[(indexPath as NSIndexPath).row]
    
    cell.textLabel?.text = picture.title
    cell.detailTextLabel?.text = picture.address
    
    if let image = picture.thumb80 {
      cell.imageView?.image = image
    }
    
    return cell
  }

  override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
    
    let picture = PicturesList.pList.pictures[(indexPath as NSIndexPath).row]
    image = picture.loadImage()
    
    return indexPath
  }
  
  override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
    if editingStyle == UITableViewCellEditingStyle.delete {
      let picture = PicturesList.pList.pictures[(indexPath as NSIndexPath).row]
      PicturesList.pList.pictures.remove(at: (indexPath as NSIndexPath).row)
      tableView.deleteRows(at: [indexPath], with: UITableViewRowAnimation.automatic)
      removeImage(picture)
      //PicturesList.pList.savePictures()
    }
  }
  
  override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    
    return true
  }
  
  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
  }
  
  override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
    
    let picture = PicturesList.pList.pictures[(indexPath as NSIndexPath).row]
    let image = picture.loadImage()
    let optionMenu = UIAlertController(title: picture.title, message: nil, preferredStyle: .actionSheet)
    
    let shareAction = UIAlertAction(title: NSLocalizedString("Share", comment: "AssetsVC: Share"),
                                     style: .default, handler: {
                                      (alert: UIAlertAction!) -> Void in
                                      if IAPHelper.iapHelper.setFullVersion {
                                        let dateString = self.dateStringFrom(picture.date as Date)
                                        var locationMessage = ""
                                        if let location = picture.location {
                                          locationMessage = self.coordinateStringFrom(location)
                                        }
                                        let message = dateString + picture.address + "\n" + locationMessage + "\nhttp://nkpro.net"
                                        if let image = image {
                                        let activityVC = UIActivityViewController(activityItems: [message,image], applicationActivities: nil)
                                          activityVC.excludedActivityTypes = [UIActivityType.saveToCameraRoll]
                                          if let popoverController = activityVC.popoverPresentationController {
                                            let cell = tableView.cellForRow(at: indexPath)
                                            popoverController.sourceView = cell
                                            if let cell = cell {
                                              popoverController.sourceRect = cell.bounds
                                            }
                                          }
                                          defer {
                                            self.present(activityVC, animated: true, completion: nil)
                                          }
                                        }
                                      } else {
                                        self.showAlert(.fullVersion)
                                      }
    })
    
    let moveAction = UIAlertAction(title: NSLocalizedString("Move to Photo", comment: "AssetsVC: Move to Photo"),
                                   style: .default, handler: {
                                    (alert: UIAlertAction!) -> Void in
                                    if IAPHelper.iapHelper.setFullVersion {
                                      if let newImage = image {
                                        PHPhotoLibrary.shared().performChanges({ () -> Void in
                                          let assetRequest = PHAssetCreationRequest.creationRequestForAsset(from: newImage)
                                          if let location = picture.location {
                                            assetRequest.location = location
                                          }
                                          assetRequest.creationDate = picture.date as Date
                                        }) { (success, error) -> Void in
                                          if let nserror = error {
                                            print("ERROR: PictureVC.SavePhoto - \(nserror)")
                                          }
                                          if success {
                                            //print("Image saved")
                                            self.removeImage(picture)
                                            PicturesList.pList.pictures.remove(at: (indexPath as NSIndexPath).row)
                                            //PicturesList.pList.savePictures()
                                            DispatchQueue.main.async {
                                              tableView.deleteRows(at: [indexPath], with: UITableViewRowAnimation.automatic)
                                            }
                                          } else {
                                            //print("Image didn't save")
                                            DispatchQueue.main.async {
                                              self.showAlert(.photoNoSaved)
                                            }
                                          }
                                        }
                                      }

                                    } else {
                                      self.showAlert(.fullVersion)
                                    }
    })
    
    let copyAction = UIAlertAction(title: NSLocalizedString("Copy to Photo", comment: "AssetsVC: Copy to Photo"),      style: .default, handler: {
      (alert: UIAlertAction!) -> Void in
      // Copy file
      if IAPHelper.iapHelper.setFullVersion {
        
        if let newImage = image {
          PHPhotoLibrary.shared().performChanges({ () -> Void in
            let assetRequest = PHAssetCreationRequest.creationRequestForAsset(from: newImage)
            if let location = picture.location {
              assetRequest.location = location
              //print("location: \(location)")
            }
            assetRequest.creationDate = picture.date as Date
          }) { (success, error) -> Void in
            if let nserror = error {
              print("ERROR: PictureVC.SavePhoto - \(nserror)")
            }
            if success {
              //print("Image saved")
              DispatchQueue.main.async {
                self.showAlert(.photoSaved)
              }
            } else {
              //print("Image didn't save")
              DispatchQueue.main.async {
                self.showAlert(.photoNoSaved)
              }
            }
          }
        }
        
      } else {
        self.showAlert(.fullVersion)
      }
    })
    let deleteAction = UIAlertAction(title: NSLocalizedString("Delete", comment: "AssetsVC: Delete"),
                                     style: .default, handler: {
                                      (alert: UIAlertAction!) -> Void in
                                      // Delete file
                                      self.removeImage(picture)
                                      PicturesList.pList.pictures.remove(at: (indexPath as NSIndexPath).row)
                                      //PicturesList.pList.savePictures()
                                      tableView.deleteRows(at: [indexPath], with: UITableViewRowAnimation.automatic)
    })
    
    let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: "AssetsVC: Cancel"),
                                     style: .cancel, handler: {
                                      (alert: UIAlertAction!) -> Void in
    })
    
    optionMenu.addAction(shareAction)
    optionMenu.addAction(moveAction)
    optionMenu.addAction(copyAction)
    optionMenu.addAction(deleteAction)
    optionMenu.addAction(cancelAction)
    
    optionMenu.view.tintColor = UIColor(red: 128.0/255.0, green: 0, blue: 128.0/255.0, alpha: 1)
    
    if let popoverController = optionMenu.popoverPresentationController {
      let cell = tableView.cellForRow(at: indexPath)
      popoverController.sourceView = cell
      if let cell = cell {
        popoverController.sourceRect = cell.bounds
      }
    }
    
    self.present(optionMenu, animated: true, completion: nil)
  }
  
  func dateStringFrom(_ date: Date) -> String {
    let dateFormater = DateFormatter()
    dateFormater.dateFormat = "yyyy/MM/dd HH:mm:ss"
    let timeString = dateFormater.string(from: date)
    return "\(timeString)\n"
  }
  
  func coordinateStringFrom(_ location: CLLocation) -> String {
    var latitudeStr = ""
    var longitudeStr = ""
    if location.coordinate.latitude >= 0 {
      latitudeStr = NSString(format: "N:%9.5lf", location.coordinate.latitude) as String
    } else {
      latitudeStr = NSString(format: "S:%9.5lf", -location.coordinate.latitude)  as String
    }
    
    if location.coordinate.longitude >= 0 {
      longitudeStr = NSString(format: "E:%9.5lf", location.coordinate.longitude) as String
    } else {
      longitudeStr = NSString(format: "W:%9.5lf", -location.coordinate.longitude)  as String
    }
    
    return "\(latitudeStr), \(longitudeStr)\n"
  }
  
  func showAlert(_ alert: AlertMessage) {
    
    var message = ""
    
    switch alert {
    case .fullVersion:
      message = NSLocalizedString("For running this function you need to go to Settings and buy Full Version", comment: "PictureVC FullVersion")
    case .photoSaved:
      message = NSLocalizedString("Photo has been copied", comment: "PictureVC PhotoSaved")
    case .photoNoSaved:
      message = NSLocalizedString("Photo hasn't been copied", comment: "PictureVC PhotoNoSaved")
    }
    
    let alert = UIAlertController(title: NSLocalizedString("Message", comment: "SettingVC Error-Title"), message: message, preferredStyle: .alert)
    
    let cancelAction = UIAlertAction(title: NSLocalizedString("OK", comment: "SettingVC Error-OK"), style: .default) { (action: UIAlertAction!) -> Void in
      
    }
    alert.addAction(cancelAction)
    self.present(alert, animated: true, completion: nil)
  }
  
}




