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
  var movieURL: URL!
  var freeSpace: Float!
  var typeSpeed: TypeSpeed!
  var activityIndicator: UIActivityIndicatorView!
  var backgroundRecordingID: UIBackgroundTaskIdentifier = UIBackgroundTaskInvalid
  
  override func viewDidLoad() {
    //print("AssetsViewController.viewDidLoad")
    super.viewDidLoad()
    // Do any additional setup after loading the view, typically from a nib.
    navigationItem.rightBarButtonItem = editButtonItem
    
    let notificationCenter = NotificationCenter.default
    notificationCenter.addObserver(self, selector: #selector(AssetsViewController.deviceOrientationDidChange), name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
  
    activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .whiteLarge)
    activityIndicator.color = UIColor(red: 252.0/255.0, green: 142.0/255.0, blue: 37.0/255.0, alpha: 1.0)
     activityIndicator.frame.origin.x = (self.view.frame.size.width / 2 - activityIndicator.frame.size.width / 2)
    activityIndicator.frame.origin.y = 150
    view.addSubview(activityIndicator)
    
  }
  
  deinit {
    //print("AssetsViewController.deinit")
    let notificationCenter = NotificationCenter.default
    notificationCenter.removeObserver(self, name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
  }
  
  override var prefersStatusBarHidden : Bool {
  
    return true
  }
  
  override var shouldAutorotate : Bool {
    return true
  }
  
  @IBAction func tapBackItem(_ sender: UIBarButtonItem) {
    dismiss(animated: true, completion: nil)
  }
  
  @IBAction func tapPhotoItem(_ sender: UIBarButtonItem) {
    if !startMediaBrowserFromViewController(self, usingDelegate: self) {
      print("SourceType is not Available")
    }
  }
  
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if segue.identifier == "playerSegue" {
      let playerVC = segue.destination as! PlayerViewController
      if let url = movieURL {
        playerVC.url = url
        playerVC.typeSpeed = typeSpeed
      }
    }
  }
  
  func deviceOrientationDidChange() {
    activityIndicator.frame.origin.x = (self.view.frame.size.width / 2 - activityIndicator.frame.size.width / 2)
  }
  
  func moveMovieToCameraRoll(_ fileURL: URL) {
    //print("CaptureManager.saveMovieToCameraRoll")

    // UIApplication.sharedApplication().networkActivityIndicatorVisible = true
    activityIndicator.startAnimating()
    self.view.isUserInteractionEnabled = false
    
    // Make sure we have time to finish saving the movie if the app is backgrounded during recording
    if UIDevice.current.isMultitaskingSupported {
      self.backgroundRecordingID = UIApplication.shared.beginBackgroundTask(expirationHandler: {})
    }
    
    PHPhotoLibrary.shared().performChanges({ () -> Void in
      PHAssetCreationRequest.creationRequestForAssetFromVideo(atFileURL: fileURL)
      }) { (success, error) -> Void in
        if let nserror = error as? NSError {
          print("ERROR: AssetsVC.moveMovieToCameraRoll - \(nserror.userInfo)")
        }
        if success {
          self.removeFile(fileURL)
        }
        DispatchQueue.main.async(execute: { () -> Void in
          // UIApplication.sharedApplication().networkActivityIndicatorVisible = false
          self.view.isUserInteractionEnabled = true
          self.activityIndicator.stopAnimating()
        })
    }
  }
  
  func copyMovieToCameraRoll(_ fileURL: URL) {
    //print("CaptureManager.saveMovieToCameraRoll")

    // UIApplication.sharedApplication().networkActivityIndicatorVisible = true
    activityIndicator.startAnimating()
    self.view.isUserInteractionEnabled = false
    
    // Make sure we have time to finish saving the movie if the app is backgrounded during recording
    if UIDevice.current.isMultitaskingSupported {
      self.backgroundRecordingID = UIApplication.shared.beginBackgroundTask(expirationHandler: {})
    }
    
    PHPhotoLibrary.shared().performChanges({ () -> Void in
      PHAssetCreationRequest.creationRequestForAssetFromVideo(atFileURL: fileURL)
      }) { (success, error) -> Void in
        if let nserror = error as? NSError {
          print("ERROR: AssetsVC.copyMovieToCameraRoll - \(nserror.userInfo)")
        }
        if UIDevice.current.isMultitaskingSupported {
          UIApplication.shared.endBackgroundTask(self.backgroundRecordingID)
          self.backgroundRecordingID = UIBackgroundTaskInvalid
        }
        DispatchQueue.main.async(execute: { () -> Void in
          // UIApplication.sharedApplication().networkActivityIndicatorVisible = false
          self.activityIndicator.stopAnimating()
          self.view.isUserInteractionEnabled = true
        })
    }
  }
  
 

  
  func removeFile(_ fileURL: URL) {
    //print("AssetsVC.removeFile")
    
    let fileManager = FileManager.default
    let filePath = fileURL.path
    if fileManager.fileExists(atPath: filePath) {
      do {
        try fileManager.removeItem(atPath: filePath)
        if let bytes = CameraViewController.deviceRemainingFreeSpaceInBytes() {
          let hMBytes = Int(bytes/10_0000_000)
          freeSpace = Float(hMBytes)/10
        }
        if UIDevice.current.isMultitaskingSupported {
          UIApplication.shared.endBackgroundTask(self.backgroundRecordingID)
          self.backgroundRecordingID = UIBackgroundTaskInvalid
        }
      } catch {
        let nserror = error as NSError
        print("ERROR: AssetsVC.removeFile - \(nserror.userInfo)")
      }
    }
  }
  
  func startMediaBrowserFromViewController(_ viewController: UIViewController, usingDelegate delegate: UINavigationControllerDelegate & UIImagePickerControllerDelegate) -> Bool {
    
    if UIImagePickerController.isSourceTypeAvailable(.savedPhotosAlbum) == false {
      return false
    }
    
    let mediaUI = PickerViewController()
    mediaUI.sourceType = .savedPhotosAlbum
    mediaUI.mediaTypes = [kUTTypeMovie as String]
    mediaUI.allowsEditing = true
    mediaUI.delegate = delegate
    
    present(mediaUI, animated: true, completion: nil)
    return true
  }
  
  func checkFreeSpace(_ asset: AssetItem) -> Bool {
    var success = false
    let assetSize = Float(asset.size) / 1_000_000_000
    if assetSize > freeSpace - 0.2 {
      let alert = UIAlertController(
        title: NSLocalizedString("No Disk Space", comment: "AssetsVC Error-Title: No Disk Space"),
        message: NSLocalizedString("Please, Clear Storage", comment: "AssetsVC Error-Message: Please, Clear Storage"),
        preferredStyle: .alert)
      let cancelAction = UIAlertAction(title: "OK", style: .default) { (action: UIAlertAction!) -> Void in
        
      }
      alert.addAction(cancelAction)
      present(alert, animated: true, completion: nil)
      
    } else {
      success = true
    }
    return success
  }
  
  func showAlert() {
    let alert = UIAlertController(title: NSLocalizedString("Message", comment: "SettingVC Error-Title"), message: NSLocalizedString("For running this function you need to go to Settings and buy Full Version", comment: "SettingVC Error-Message"), preferredStyle: .alert)
    
    let cancelAction = UIAlertAction(title: NSLocalizedString("OK", comment: "SettingVC Error-OK"), style: .default) { (action: UIAlertAction!) -> Void in
      
    }
    alert.addAction(cancelAction)
    self.present(alert, animated: true, completion: nil)
  }
  
  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
  }
  
  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return assetItemsList.count
  }
  
  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    //print("AssetsVC.cellForRowAtIndexPath: \(indexPath.row)")
    let cell = tableView.dequeueReusableCell(withIdentifier: "AssetCell", for: indexPath) as! VideoCell
    let asset = assetItemsList[(indexPath as NSIndexPath).row]
    
    let words = asset.title.components(separatedBy: ".")
    if words.count == 2 {
      cell.descriptionLabel.text = words[0]
    } else {
      cell.descriptionLabel.text = asset.title
    }

    if asset.isLocked {
      cell.lockImageView.isHidden = false
    } else {
      cell.lockImageView.isHidden = true
    }
    cell.sizeLabel.text = "\(asset.size/1000000) M"
    
    if let image = asset.image {
      cell.photoImageView.image = image
    }
  
    return cell
  }
  
  override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
    if editingStyle == UITableViewCellEditingStyle.delete {
      let asset = assetItemsList[(indexPath as NSIndexPath).row]
      if !asset.isLocked {
        let movieURL = asset.url
        removeFile(movieURL as URL)
        assetItemsList.remove(at: (indexPath as NSIndexPath).row)
        tableView.deleteRows(at: [indexPath], with: UITableViewRowAnimation.automatic)
      }
    }
  }
  
  override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    let asset = assetItemsList[(indexPath as NSIndexPath).row]
    if asset.isLocked {
      return false
    }
    return true
  }
  
  override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
    
    let asset = assetItemsList[(indexPath as NSIndexPath).row]
    let movieURL = asset.url
    let optionMenu = UIAlertController(title: asset.title, message: nil, preferredStyle: .actionSheet)
    
    let moveAction = UIAlertAction(title: NSLocalizedString("Move to Photo", comment: "AssetsVC: Move to Photo"),
      style: .default, handler: {
      (alert: UIAlertAction!) -> Void in
      
        if IAPHelper.iapHelper.setFullVersion {
          if self.checkFreeSpace(asset) {
            self.moveMovieToCameraRoll(movieURL as URL)
            self.assetItemsList.remove(at: (indexPath as NSIndexPath).row)
            tableView.deleteRows(at: [indexPath], with: UITableViewRowAnimation.automatic)
          }
        } else {
          self.showAlert()
        }
    })
  
    let copyAction = UIAlertAction(title: NSLocalizedString("Copy to Photo", comment: "AssetsVC: Copy to Photo"),      style: .default, handler: {
      (alert: UIAlertAction!) -> Void in
      // Copy file
      if IAPHelper.iapHelper.setFullVersion {
        if self.checkFreeSpace(asset) {
          self.copyMovieToCameraRoll(movieURL as URL)
        }
      } else {
        self.showAlert()
      }
    })
    let deleteAction = UIAlertAction(title: NSLocalizedString("Delete", comment: "AssetsVC: Delete"),
      style: .default, handler: {
      (alert: UIAlertAction!) -> Void in
      // Delete file
      self.removeFile(movieURL as URL)
      self.assetItemsList.remove(at: (indexPath as NSIndexPath).row)
      tableView.deleteRows(at: [indexPath], with: UITableViewRowAnimation.automatic)
    })
    
    let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: "AssetsVC: Cancel"),
      style: .cancel, handler: {
      (alert: UIAlertAction!) -> Void in
    })
    
    let lockAction = UIAlertAction(title: "Lock", style: .default, handler: {
      (alert: UIAlertAction!) -> Void in
      // Lock file
      asset.isLocked = true
      if !LockedList.lockList.lockVideo.contains(asset.title) {
        LockedList.lockList.lockVideo.append(asset.title)
        LockedList.lockList.saveLockedVideo()
      }
      self.tableView.reloadData()
    })
    
    let unlockAction = UIAlertAction(title: "Unock", style: .default, handler: {
      (alert: UIAlertAction!) -> Void in
      // Unock file
      asset.isLocked = false
      if let index = LockedList.lockList.lockVideo.index(of: asset.title) {
        // print("Index: \(index)")
        LockedList.lockList.lockVideo.remove(at: index)
        LockedList.lockList.saveLockedVideo()
        self.tableView.reloadData()
      }
    })

    
    optionMenu.addAction(copyAction)
    
    if asset.isLocked {
      optionMenu.addAction(unlockAction)
    } else {
      optionMenu.addAction(moveAction)
      optionMenu.addAction(lockAction)
      optionMenu.addAction(deleteAction)
    }
    
    optionMenu.addAction(cancelAction)
    
    if let popoverController = optionMenu.popoverPresentationController {
      let cell = tableView.cellForRow(at: indexPath)
      popoverController.sourceView = cell
      if let cell = cell {
        popoverController.sourceRect = cell.bounds
      }
    }
    
    self.present(optionMenu, animated: true, completion: nil)
  }
  
  override func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
    
    let asset = assetItemsList[(indexPath as NSIndexPath).row]
    movieURL = asset.url as URL!
    
    return indexPath
  }
}

// MARK: - UIScrollViewDelegate

extension AssetsViewController {
  override func scrollViewDidScroll(_ scrollView: UIScrollView) {
    //print("\(scrollView.contentOffset)")
    activityIndicator.frame.origin.y = scrollView.contentOffset.y + 150
  }
}

// MARK: - UIImagePickerControllerDelegate

extension AssetsViewController: UIImagePickerControllerDelegate {
  
  func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
    
    let mediaType = info[UIImagePickerControllerMediaType] as! NSString
    
    dismiss(animated: true) {
      
      if mediaType == kUTTypeMovie {
        self.movieURL = info[UIImagePickerControllerMediaURL] as! URL
        self.performSegue(withIdentifier: "playerSegue", sender: nil)
      }
    }
  }
}




