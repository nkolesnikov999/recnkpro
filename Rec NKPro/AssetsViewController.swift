//
//  AssetsViewController.swift
//  FixDrive
//
//  Created by NK on 16.08.15.
//  Copyright © 2015 Nikolay Kolesnikov. All rights reserved.
//

/*
*
*
* http://stackoverflow.com/questions/31537311/sharing-a-file-through-my-ios-application-with-uiactivityviewcontroller
*
*
*/

import iAd
import UIKit
import Photos
import AVFoundation
import MobileCoreServices

class AssetsViewController : UITableViewController, UINavigationControllerDelegate {
  
  var assetItemsList: [AssetItem]!
  var movieURL: NSURL!
  var freeSpace: Float!
  var typeSpeed: TypeSpeed!
  var activityIndicator: UIActivityIndicatorView!
  var backgroundRecordingID: UIBackgroundTaskIdentifier = UIBackgroundTaskInvalid
  
  override func viewDidLoad() {
    //print("AssetsViewController.viewDidLoad")
    super.viewDidLoad()
    // Do any additional setup after loading the view, typically from a nib.
    navigationItem.rightBarButtonItem = editButtonItem()
    
    let notificationCenter = NSNotificationCenter.defaultCenter()
    notificationCenter.addObserver(self, selector: #selector(AssetsViewController.deviceOrientationDidChange), name: UIDeviceOrientationDidChangeNotification, object: nil)
  
    activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .WhiteLarge)
    activityIndicator.color = UIColor(red: 252.0/255.0, green: 142.0/255.0, blue: 37.0/255.0, alpha: 1.0)
     activityIndicator.frame.origin.x = (self.view.frame.size.width / 2 - activityIndicator.frame.size.width / 2)
    activityIndicator.frame.origin.y = 150
    view.addSubview(activityIndicator)
    
  }
  
  deinit {
    //print("AssetsViewController.deinit")
    let notificationCenter = NSNotificationCenter.defaultCenter()
    notificationCenter.removeObserver(self, name: UIDeviceOrientationDidChangeNotification, object: nil)
  }
  
  override func prefersStatusBarHidden() -> Bool {
  
    return true
  }
  
  override func shouldAutorotate() -> Bool {
    return true
  }
  
  @IBAction func tapBackItem(sender: UIBarButtonItem) {
    dismissViewControllerAnimated(true, completion: nil)
  }
  
  @IBAction func tapPhotoItem(sender: UIBarButtonItem) {
    startMediaBrowserFromViewController(self, usingDelegate: self)
  }
  
  override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
    if segue.identifier == "playerSegue" {
      let playerVC = segue.destinationViewController as! PlayerViewController
      if let url = movieURL {
        playerVC.url = url
        playerVC.typeSpeed = typeSpeed
      }
    }
  }
  
  func deviceOrientationDidChange() {
    activityIndicator.frame.origin.x = (self.view.frame.size.width / 2 - activityIndicator.frame.size.width / 2)
  }
  
  func moveMovieToCameraRoll(fileURL: NSURL) {
    //print("CaptureManager.saveMovieToCameraRoll")

    // UIApplication.sharedApplication().networkActivityIndicatorVisible = true
    activityIndicator.startAnimating()
    self.view.userInteractionEnabled = false
    
    // Make sure we have time to finish saving the movie if the app is backgrounded during recording
    if UIDevice.currentDevice().multitaskingSupported {
      self.backgroundRecordingID = UIApplication.sharedApplication().beginBackgroundTaskWithExpirationHandler({})
    }
    
    PHPhotoLibrary.sharedPhotoLibrary().performChanges({ () -> Void in
      PHAssetCreationRequest.creationRequestForAssetFromVideoAtFileURL(fileURL)
      }) { (success, error) -> Void in
        if let nserror = error {
          print("ERROR: AssetsVC.moveMovieToCameraRoll - \(nserror.userInfo)")
        }
        if success {
          self.removeFile(fileURL)
        }
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
          // UIApplication.sharedApplication().networkActivityIndicatorVisible = false
          self.view.userInteractionEnabled = true
          self.activityIndicator.stopAnimating()
        })
    }
  }
  
  func copyMovieToCameraRoll(fileURL: NSURL) {
    //print("CaptureManager.saveMovieToCameraRoll")

    // UIApplication.sharedApplication().networkActivityIndicatorVisible = true
    activityIndicator.startAnimating()
    self.view.userInteractionEnabled = false
    
    // Make sure we have time to finish saving the movie if the app is backgrounded during recording
    if UIDevice.currentDevice().multitaskingSupported {
      self.backgroundRecordingID = UIApplication.sharedApplication().beginBackgroundTaskWithExpirationHandler({})
    }
    
    PHPhotoLibrary.sharedPhotoLibrary().performChanges({ () -> Void in
      PHAssetCreationRequest.creationRequestForAssetFromVideoAtFileURL(fileURL)
      }) { (success, error) -> Void in
        if let nserror = error {
          print("ERROR: AssetsVC.copyMovieToCameraRoll - \(nserror.userInfo)")
        }
        if UIDevice.currentDevice().multitaskingSupported {
          UIApplication.sharedApplication().endBackgroundTask(self.backgroundRecordingID)
          self.backgroundRecordingID = UIBackgroundTaskInvalid
        }
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
          // UIApplication.sharedApplication().networkActivityIndicatorVisible = false
          self.activityIndicator.stopAnimating()
          self.view.userInteractionEnabled = true
        })
    }
  }
  
  func removeFile(fileURL: NSURL) {
    //print("AssetsVC.removeFile")
    
    let fileManager = NSFileManager.defaultManager()
    let filePath = fileURL.path
    if fileManager.fileExistsAtPath(filePath!) {
      do {
        try fileManager.removeItemAtPath(filePath!)
        if let bytes = CameraViewController.deviceRemainingFreeSpaceInBytes() {
          let hMBytes = Int(bytes/10_0000_000)
          freeSpace = Float(hMBytes)/10
        }
        if UIDevice.currentDevice().multitaskingSupported {
          UIApplication.sharedApplication().endBackgroundTask(self.backgroundRecordingID)
          self.backgroundRecordingID = UIBackgroundTaskInvalid
        }
      } catch {
        let nserror = error as NSError
        print("ERROR: AssetsVC.removeFile - \(nserror.userInfo)")
      }
    }
  }
  
  func startMediaBrowserFromViewController(viewController: UIViewController, usingDelegate delegate: protocol<UINavigationControllerDelegate, UIImagePickerControllerDelegate>) -> Bool {
    
    if UIImagePickerController.isSourceTypeAvailable(.SavedPhotosAlbum) == false {
      return false
    }
    
    let mediaUI = PickerViewController()
    mediaUI.sourceType = .SavedPhotosAlbum
    mediaUI.mediaTypes = [kUTTypeMovie as String]
    mediaUI.allowsEditing = true
    mediaUI.delegate = delegate
    
    presentViewController(mediaUI, animated: true, completion: nil)
    return true
  }
  
  func checkFreeSpace(asset: AssetItem) -> Bool {
    var success = false
    let assetSize = Float(asset.size) / 1_000_000_000
    if assetSize > freeSpace - 0.2 {
      let alert = UIAlertController(
        title: NSLocalizedString("No Disk Space", comment: "AssetsVC Error-Title: No Disk Space"),
        message: NSLocalizedString("Please, Clear Storage", comment: "AssetsVC Error-Message: Please, Clear Storage"),
        preferredStyle: .Alert)
      let cancelAction = UIAlertAction(title: "OK", style: .Default) { (action: UIAlertAction!) -> Void in
        
      }
      alert.addAction(cancelAction)
      presentViewController(alert, animated: true, completion: nil)
      
    } else {
      success = true
    }
    return success
  }
  
  func showAlert() {
    let alert = UIAlertController(title: NSLocalizedString("Message", comment: "SettingVC Error-Title"), message: NSLocalizedString("For running this function you need to go to Settings and buy Full Version", comment: "SettingVC Error-Message"), preferredStyle: .Alert)
    
    let cancelAction = UIAlertAction(title: NSLocalizedString("OK", comment: "SettingVC Error-OK"), style: .Default) { (action: UIAlertAction!) -> Void in
      
    }
    alert.addAction(cancelAction)
    self.presentViewController(alert, animated: true, completion: nil)
  }
  
  override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
    tableView.deselectRowAtIndexPath(indexPath, animated: true)
  }
  
  override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return assetItemsList.count
  }
  
  override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    //print("AssetsVC.cellForRowAtIndexPath: \(indexPath.row)")
    let cell = tableView.dequeueReusableCellWithIdentifier("AssetCell", forIndexPath: indexPath) as UITableViewCell
    let asset = assetItemsList[indexPath.row]
    
    let words = asset.title.componentsSeparatedByString(".")
    if words.count == 2 {
      cell.textLabel?.text = words[0]
    } else {
      cell.textLabel?.text = asset.title
    }
    
    cell.detailTextLabel?.text = "\(asset.size/1000000) M"
    if let image = asset.image {
      cell.imageView?.image = image
    }
  
    return cell
  }
  
  override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
    if editingStyle == UITableViewCellEditingStyle.Delete {
      let asset = assetItemsList[indexPath.row]
      let movieURL = asset.url
      removeFile(movieURL)
      assetItemsList.removeAtIndex(indexPath.row)
      tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.Automatic)
    }
  }
  
  override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
    
    return true
  }
  
  override func tableView(tableView: UITableView, accessoryButtonTappedForRowWithIndexPath indexPath: NSIndexPath) {
    
    let asset = assetItemsList[indexPath.row]
    let movieURL = asset.url
    let optionMenu = UIAlertController(title: asset.title, message: nil, preferredStyle: .ActionSheet)
    
    let moveAction = UIAlertAction(title: NSLocalizedString("Move to Photo", comment: "AssetsVC: Move to Photo"),
      style: .Default, handler: {
      (alert: UIAlertAction!) -> Void in
      
        if IAPHelper.iapHelper.setFullVersion {
          if self.checkFreeSpace(asset) {
            self.moveMovieToCameraRoll(movieURL)
            self.assetItemsList.removeAtIndex(indexPath.row)
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.Automatic)
          }
        } else {
          self.showAlert()
        }
    })
  
    let copyAction = UIAlertAction(title: NSLocalizedString("Copy to Photo", comment: "AssetsVC: Copy to Photo"),      style: .Default, handler: {
      (alert: UIAlertAction!) -> Void in
      // Copy file
      if IAPHelper.iapHelper.setFullVersion {
        if self.checkFreeSpace(asset) {
          self.copyMovieToCameraRoll(movieURL)
        }
      } else {
        self.showAlert()
      }
    })
    let deleteAction = UIAlertAction(title: NSLocalizedString("Delete", comment: "AssetsVC: Delete"),
      style: .Default, handler: {
      (alert: UIAlertAction!) -> Void in
      // Delete file
      self.removeFile(movieURL)
      self.assetItemsList.removeAtIndex(indexPath.row)
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
  
  override func tableView(tableView: UITableView, willSelectRowAtIndexPath indexPath: NSIndexPath) -> NSIndexPath? {
    
    let asset = assetItemsList[indexPath.row]
    movieURL = asset.url
    
    return indexPath
  }
}

// MARK: - UIScrollViewDelegate

extension AssetsViewController {
  override func scrollViewDidScroll(scrollView: UIScrollView) {
    //print("\(scrollView.contentOffset)")
    activityIndicator.frame.origin.y = scrollView.contentOffset.y + 150
  }
}

// MARK: - UIImagePickerControllerDelegate

extension AssetsViewController: UIImagePickerControllerDelegate {
  
  
  func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {
    
    let mediaType = info[UIImagePickerControllerMediaType] as! NSString
    
    dismissViewControllerAnimated(true) {
      
      if mediaType == kUTTypeMovie {
        self.movieURL = info[UIImagePickerControllerMediaURL] as! NSURL
        self.performSegueWithIdentifier("playerSegue", sender: nil)
      }
    }
  }
}




