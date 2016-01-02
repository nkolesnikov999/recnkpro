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

import UIKit
import Photos
import AVFoundation
import MobileCoreServices

class AssetsViewController : UIViewController {
  
  var assetItemsList: [AssetItem]!
  var movieURL: NSURL!
  var freeSpace: Float!
  
  @IBOutlet weak var tableView: UITableView!
  @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
  
  override func viewDidLoad() {
    //print("AssetsViewController.viewDidLoad")
    super.viewDidLoad()
    // Do any additional setup after loading the view, typically from a nib.
    
  }
  
  deinit {
    //print("AssetsViewController.deinit")
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
      }
    }
  }
  
  func moveMovieToCameraRoll(fileURL: NSURL) {
    //print("CaptureManager.saveMovieToCameraRoll")
    self.activityIndicator.startAnimating()
    self.view.userInteractionEnabled = false
    
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
          self.activityIndicator.stopAnimating()
          self.view.userInteractionEnabled = true
        })
    }
  }
  
  func copyMovieToCameraRoll(fileURL: NSURL) {
    //print("CaptureManager.saveMovieToCameraRoll")
    self.activityIndicator.startAnimating()
    self.view.userInteractionEnabled = false
    
    PHPhotoLibrary.sharedPhotoLibrary().performChanges({ () -> Void in
      PHAssetCreationRequest.creationRequestForAssetFromVideoAtFileURL(fileURL)
      }) { (success, error) -> Void in
        if let nserror = error {
          print("ERROR: AssetsVC.copyMovieToCameraRoll - \(nserror.userInfo)")
        }
        
        dispatch_async(dispatch_get_main_queue(), { () -> Void in
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
  
}

// MARK: - UITableViewDataSource

extension AssetsViewController : UITableViewDataSource {
  
  func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
    tableView.deselectRowAtIndexPath(indexPath, animated: true)
  }
  
  func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return assetItemsList.count
  }
  
  func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    //print("AssetsVC.cellForRowAtIndexPath: \(indexPath.row)")
    let cell = tableView.dequeueReusableCellWithIdentifier("AssetCell", forIndexPath: indexPath) as UITableViewCell
    let asset = assetItemsList[indexPath.row]
    
    cell.textLabel?.text = asset.title
    cell.detailTextLabel?.text = "\(asset.size/1000000) M"
    if let image = asset.image {
      cell.imageView?.image = image
    }
  
    return cell
  }
  
  func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
    if editingStyle == UITableViewCellEditingStyle.Delete {
      let asset = assetItemsList[indexPath.row]
      let movieURL = asset.url
      removeFile(movieURL)
      assetItemsList.removeAtIndex(indexPath.row)
      tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.Automatic)
    }
  }
}

// MARK: - UITableViewDelegate

extension AssetsViewController : UITableViewDelegate {
  
  func tableView(tableView: UITableView, accessoryButtonTappedForRowWithIndexPath indexPath: NSIndexPath) {
    
    let asset = assetItemsList[indexPath.row]
    let movieURL = asset.url
    let optionMenu = UIAlertController(title: asset.title, message: nil, preferredStyle: .ActionSheet)
    
    let moveAction = UIAlertAction(title: NSLocalizedString("Move to Photo", comment: "AssetsVC: Move to Photo"),
      style: .Default, handler: {
      (alert: UIAlertAction!) -> Void in
      
      if self.checkFreeSpace(asset) {
        self.moveMovieToCameraRoll(movieURL)
        self.assetItemsList.removeAtIndex(indexPath.row)
        tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.Automatic)
      }
    })
    let copyAction = UIAlertAction(title: NSLocalizedString("Copy to Photo", comment: "AssetsVC: Copy to Photo"),      style: .Default, handler: {
      (alert: UIAlertAction!) -> Void in
      // Copy file
      if self.checkFreeSpace(asset) {
        self.copyMovieToCameraRoll(movieURL)
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
  
  func tableView(tableView: UITableView, willSelectRowAtIndexPath indexPath: NSIndexPath) -> NSIndexPath? {
    
    let asset = assetItemsList[indexPath.row]
    movieURL = asset.url
    
    return indexPath
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

// MARK: - UINavigationControllerDelegate

extension AssetsViewController: UINavigationControllerDelegate {
}



