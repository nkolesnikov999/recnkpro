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
    case FullVersion = 0
    case PhotoSaved = 1
    case PhotoNoSaved = 2
  }

  var picturesList: [Picture]!
  var image: UIImage?
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // Do any additional setup after loading the view.
    navigationItem.rightBarButtonItem = editButtonItem()
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  override func prefersStatusBarHidden() -> Bool {
    
    return false
  }
  
  override func shouldAutorotate() -> Bool {
    return true
  }
  
  @IBAction func tapCamera(sender: UIBarButtonItem) {
    dismissViewControllerAnimated(true, completion: nil)
  }
  
  func removeImage(picture: Picture) {
    
    let directory = NSFileManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first!
    guard let path = directory.URLByAppendingPathComponent(picture.title).path else { return }
    
    let fileManager = NSFileManager.defaultManager()
    if fileManager.fileExistsAtPath(path) {
      do {
        try fileManager.removeItemAtPath(path)
        print("Image deleted")
      } catch {
        let nserror = error as NSError
        print("ERROR: PictureVC.removeFile - \(nserror.userInfo)")
      }
    }

  }
  
  func savePictures() {
    let isSuccessfulSave = NSKeyedArchiver.archiveRootObject(picturesList, toFile: Picture.ArchiveURL.path!)
    if !isSuccessfulSave {
      print("Failed to save pictures...")
    } else {
      print("Pictures saved")
    }
  }
  
  override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
    if segue.identifier == "pictureSegue" {
      if let destVC = segue.destinationViewController as? ZoomedPhotoViewController {
        if let image = image {
          destVC.image = image
        }
      }
    }
  }

  override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return picturesList.count
  }
  
  override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCellWithIdentifier("PictureCell", forIndexPath: indexPath) as UITableViewCell
    let picture = picturesList[indexPath.row]
    
    cell.textLabel?.text = picture.title
    cell.detailTextLabel?.text = picture.address
    
    if let image = picture.thumb80 {
      cell.imageView?.image = image
    }
    
    return cell
  }

  override func tableView(tableView: UITableView, willSelectRowAtIndexPath indexPath: NSIndexPath) -> NSIndexPath? {
    
    let picture = picturesList[indexPath.row]
    image = picture.loadImage()
    
    return indexPath
  }
  
  override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
    if editingStyle == UITableViewCellEditingStyle.Delete {
      let picture = picturesList[indexPath.row]
      removeImage(picture)
      picturesList.removeAtIndex(indexPath.row)
      savePictures()
      tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.Automatic)
      
    }
  }
  
  override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
    
    return true
  }
  
  override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
    tableView.deselectRowAtIndexPath(indexPath, animated: true)
  }
  
  override func tableView(tableView: UITableView, accessoryButtonTappedForRowWithIndexPath indexPath: NSIndexPath) {
    
    let picture = picturesList[indexPath.row]
    let image = picture.loadImage()
    let optionMenu = UIAlertController(title: picture.title, message: nil, preferredStyle: .ActionSheet)
    
    let moveAction = UIAlertAction(title: NSLocalizedString("Move to Photo", comment: "AssetsVC: Move to Photo"),
                                   style: .Default, handler: {
                                    (alert: UIAlertAction!) -> Void in
                                    // TODO:
                                    if IAPHelper.iapHelper.setFullVersion {
                                      if let newImage = image {
                                        PHPhotoLibrary.sharedPhotoLibrary().performChanges({ () -> Void in
                                          let assetRequest = PHAssetCreationRequest.creationRequestForAssetFromImage(newImage)
                                          if let location = picture.location {
                                            assetRequest.location = location
                                          }
                                          assetRequest.creationDate = picture.date
                                        }) { (success, error) -> Void in
                                          if let nserror = error {
                                            print("ERROR: PictureVC.SavePhoto - \(nserror)")
                                          }
                                          if success {
                                            print("Image saved")
                                            self.removeImage(picture)
                                            self.picturesList.removeAtIndex(indexPath.row)
                                            self.savePictures()
                                            dispatch_async(dispatch_get_main_queue()) {
                                              tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.Automatic)
                                            }
                                          } else {
                                            print("Image didn't save")
                                            dispatch_async(dispatch_get_main_queue()) {
                                              self.showAlert(.PhotoNoSaved)
                                            }
                                          }
                                        }
                                      }

                                    } else {
                                      self.showAlert(.FullVersion)
                                    }
    })
    
    let copyAction = UIAlertAction(title: NSLocalizedString("Copy to Photo", comment: "AssetsVC: Copy to Photo"),      style: .Default, handler: {
      (alert: UIAlertAction!) -> Void in
      // Copy file
      // TODO:
      if IAPHelper.iapHelper.setFullVersion {
        
        if let newImage = image {
          PHPhotoLibrary.sharedPhotoLibrary().performChanges({ () -> Void in
            let assetRequest = PHAssetCreationRequest.creationRequestForAssetFromImage(newImage)
            if let location = picture.location {
              assetRequest.location = location
              //print("location: \(location)")
            }
            assetRequest.creationDate = picture.date
          }) { (success, error) -> Void in
            if let nserror = error {
              print("ERROR: PictureVC.SavePhoto - \(nserror)")
            }
            if success {
              print("Image saved")
              dispatch_async(dispatch_get_main_queue()) {
                self.showAlert(.PhotoSaved)
              }
            } else {
              print("Image didn't save")
              dispatch_async(dispatch_get_main_queue()) {
                self.showAlert(.PhotoNoSaved)
              }
            }
          }
        }
        
      } else {
        self.showAlert(.FullVersion)
      }
    })
    let deleteAction = UIAlertAction(title: NSLocalizedString("Delete", comment: "AssetsVC: Delete"),
                                     style: .Default, handler: {
                                      (alert: UIAlertAction!) -> Void in
                                      // Delete file
                                      self.removeImage(picture)
                                      self.picturesList.removeAtIndex(indexPath.row)
                                      self.savePictures()
                                      tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.Automatic)
    })
    
    let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: "AssetsVC: Cancel"),
                                     style: .Cancel, handler: {
                                      (alert: UIAlertAction!) -> Void in
    })
    
    optionMenu.addAction(moveAction)
    optionMenu.addAction(copyAction)
    optionMenu.addAction(deleteAction)
    optionMenu.addAction(cancelAction)
    
    optionMenu.view.tintColor = UIColor(red: 128.0/255.0, green: 0, blue: 128.0/255.0, alpha: 1)
    
    if let popoverController = optionMenu.popoverPresentationController {
      let cell = tableView.cellForRowAtIndexPath(indexPath)
      popoverController.sourceView = cell
      if let cell = cell {
        popoverController.sourceRect = cell.bounds
      }
    }
    
    self.presentViewController(optionMenu, animated: true, completion: nil)
  }
  
  func showAlert(alert: AlertMessage) {
    
    var message = ""
    
    switch alert {
    case .FullVersion:
      message = NSLocalizedString("For running this function you need to go to Settings and buy Full Version", comment: "PictureVC FullVersion")
    case .PhotoSaved:
      message = NSLocalizedString("Photo has been copied", comment: "PictureVC PhotoSaved")
    case .PhotoNoSaved:
      message = NSLocalizedString("Photo hasn't been copied", comment: "PictureVC PhotoNoSaved")
    }
    
    let alert = UIAlertController(title: NSLocalizedString("Message", comment: "SettingVC Error-Title"), message: message, preferredStyle: .Alert)
    
    let cancelAction = UIAlertAction(title: NSLocalizedString("OK", comment: "SettingVC Error-OK"), style: .Default) { (action: UIAlertAction!) -> Void in
      
    }
    alert.addAction(cancelAction)
    self.presentViewController(alert, animated: true, completion: nil)
  }
  
}




