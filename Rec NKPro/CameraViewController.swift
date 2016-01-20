//
//  CameraViewController.swift
//  FixDrive
//
//  Created by NK on 16.08.15.
//  Copyright © 2015 Nikolay Kolesnikov. All rights reserved.
//

/*
* http://stackoverflow.com/questions/5712527/how-to-detect-total-available-free-disk-space-on-the-iphone-ipad-device
* http://stackoverflow.com/questions/11807295/how-to-get-real-time-battery-level-on-ios
* http://www.raywenderlich.com/94404/play-record-merge-videos-ios-swift
* http://www.raywenderlich.com/108766/uiappearance-tutorial
*
*/

import UIKit
import CoreTelephony
import CoreLocation
import AVFoundation

let QualityModeKey = "QualityModeKey"
let TypeCameraKey = "TypeCameraKey"
let AutofocusingKey = "AutofocusingKey"
let MinIntervalLocationsKey = "MinIntervalLocationsKey"
let TypeSpeedKey = "TypeSpeedKey"
let MaxRecordingTimeKey = "MaxRecordingTimeKey"
let MaxNumberFilesKey = "MaxNumberFilesKey"
let LayerOpacityValueKey = "LayerOpacityValueKey"
let OdometerMetersKey = "OdometerMetersKey"
let TextOnVideoKey = "TextOnVideoKey"
let LogotypeKey = "LogotypeKey"


class CameraViewController : UIViewController, SettingsControllerDelegate {
  
  var settings = Settings()
  var layer: AVCaptureVideoPreviewLayer?
  var captureManager: CaptureManager?
  var backgroundRecordingID: UIBackgroundTaskIdentifier = UIBackgroundTaskInvalid
  var mustRecord = false
  var resetRecordingTimer = false
  var freeSpace: Float = 0
  
  var recordingTimer: NSTimer?
  var updateTimeTimer: NSTimer?
  var updateLocationTimer: NSTimer?
  var updateBatteryAndDiskTimer: NSTimer?
  var removeControlViewTimer: NSTimer?
  
  var callCenter: CTCallCenter!
  var assetItemsList: [AssetItem]!
  var odometer: Odometer!
  
  let kUpdateTimeInterval: NSTimeInterval = 1
  let kUpdateLocationInterval: NSTimeInterval = 3.0
  let kUpdateBatteryAndDiskInterval: NSTimeInterval = 30.0
  let kRemoveControlViewInterval: NSTimeInterval = 10.0
  
  
  
  @IBOutlet weak var previewView: UIView!
  @IBOutlet weak var speedView: UIView!
  @IBOutlet weak var speedLabel: UILabel!
  @IBOutlet weak var unitsSpeedLabel: UILabel!
  @IBOutlet weak var odometerLabel: UILabel!
  @IBOutlet weak var settingsButton: UIButton!
  @IBOutlet weak var recordButton: UIButton!
  @IBOutlet weak var layerOpacitySlider: UISlider!
  @IBOutlet weak var controlView: UIView!
  @IBOutlet weak var timeLabel: UILabel!
  @IBOutlet weak var frameRateLabel: UILabel!
  @IBOutlet weak var resolutionLabel: UILabel!
  @IBOutlet weak var textLabel: UILabel!
  @IBOutlet weak var backButton: UIButton!
  @IBOutlet weak var fillDiskLabel: UILabel!
  @IBOutlet weak var batteryLabel: UILabel!
  @IBOutlet weak var controlViewConstraint: NSLayoutConstraint!
  

  //MARK: - View Loading
  
  override func viewDidLoad() {
    //print("CameraVC.viewDidLoad")
    super.viewDidLoad()
    
    resolutionLabel.layer.backgroundColor = UIColor(red: 176.0/255.0, green: 176.0/255.0, blue: 176.0/255.0, alpha: 0.5).CGColor
    resolutionLabel.layer.cornerRadius = 10.0
    
    textLabel.layer.backgroundColor = UIColor(red: 176.0/255.0, green: 176.0/255.0, blue: 176.0/255.0, alpha: 0.5).CGColor
    textLabel.layer.cornerRadius = 10.0
    
    timeLabel.layer.backgroundColor = UIColor(red: 176.0/255.0, green: 176.0/255.0, blue: 176.0/255.0, alpha: 0.5).CGColor
    timeLabel.layer.cornerRadius = 13.0
    
    odometerLabel.layer.backgroundColor = UIColor(red: 176.0/255.0, green: 176.0/255.0, blue: 176.0/255.0, alpha: 0.5).CGColor
    odometerLabel.layer.cornerRadius = 18.0
    
    // Keep track of changes to the device orientation so we can update the capture manager
    let notificationCenter = NSNotificationCenter.defaultCenter()
    notificationCenter.addObserver(self, selector: "deviceOrientationDidChange", name: UIDeviceOrientationDidChangeNotification, object: nil)
    notificationCenter.addObserver(self, selector: "applicationDidBecomeActive:", name: UIApplicationDidBecomeActiveNotification, object: UIApplication.sharedApplication())
    notificationCenter.addObserver(self, selector: "applicationWillResignActive:", name: UIApplicationWillResignActiveNotification, object: UIApplication.sharedApplication())
    
    UIDevice.currentDevice().beginGeneratingDeviceOrientationNotifications()
    
    // Load settings if they are not we'll use defaults that was define in Settings
    loadSettings()
    
    callCenter = CTCallCenter()
    callCenter.callEventHandler = { (call: CTCall) in
      self.treatPhoneCall(call)
    }
    
    speedLabel.text = ""
    speedView.hidden = true
    
    timeLabel.text = "2016/01/01 00:00:00"
    batteryLabel.text = "80"
    fillDiskLabel.text = "0.0"
    
    frameRateLabel.text = "0.0"
    frameRateLabel.textColor = UIColor.redColor()

    recordButton.setImage(UIImage(named: "StartNormal"), forState: .Normal)
    //controlView.hidden = true
    
    // Initialize the class responsible for managing AV capture session and asset writer
    captureManager = CaptureManager()
    captureManager?.delegate = self
    captureManager?.minInterval = settings.minIntervalLocations
    captureManager?.typeSpeed = settings.typeSpeed
    captureManager?.autofocusing = settings.autofocusing
    captureManager?.typeCamera = settings.typeCamera
    captureManager?.logotype = settings.logotype
    captureManager?.textOnVideo = settings.textOnVideo
    
    // Setup and start the capture session
    captureManager?.setupAndStartCaptureSession()
    
    odometer = Odometer(distance: settings.odometerMeters)
    createOdometerLabel(settings.odometerMeters)
    
    setResolutionAndTextLabels()
  }
  
  
  override func viewDidAppear(animated: Bool) {
    //print("CameraVC.viewDidAppear")
    super.viewDidAppear(animated)
    
    createOdometerLabel(settings.odometerMeters)
    speedLabel.text = ""
    timeLabel.text = ""
    
    // Setup preview layer
    setupPreviewLayer()
    
    updateBatteryAndDiskLabels()
    timeLabelUpdate()
    controlViewConstraint.constant = 0
    
    setResolutionAndTextLabels()
    
    // Start update timers label
    updateTimeTimer = NSTimer.scheduledTimerWithTimeInterval(kUpdateTimeInterval, target: self, selector: Selector("timeLabelUpdate"), userInfo: nil, repeats: true)
    updateBatteryAndDiskTimer = NSTimer.scheduledTimerWithTimeInterval(kUpdateBatteryAndDiskInterval, target: self, selector: Selector("updateBatteryAndDiskLabels"), userInfo: nil, repeats: true)
    removeControlViewTimer = nil
    
    controlView.hidden = false
    
    createMovieContents()
    
    if !IAPHelper.iapHelper.setRemoveAd {
      UIViewController.prepareInterstitialAds()
    }
  }
  
  override func viewWillDisappear(animated: Bool) {
    //print("CameraVC.viewWillDisappear")
    super.viewWillDisappear(animated)
    
    //Stop update timer label
    stopTimer(&updateTimeTimer)
    stopTimer(&updateLocationTimer)
    stopTimer(&removeControlViewTimer)
    stopTimer(&recordingTimer)
  }
  
  deinit {
    //print("CameraVC.deinit")
    cleanup()
  }
  
  override func prefersStatusBarHidden() -> Bool {
    //print("CameraVC.prefersStatusBarHidden")
    return true
  }
  
  
  override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
    //print("CameraVC.supportedInterfaceOrientations")
    return .All
  }
  
  
  override func shouldAutorotate() -> Bool {
    //print("CameraVC.shouldAutorotate")
    if let cm = captureManager {
      return !cm.recording
    }
    return true
  }
  
  func cleanup() {
    //print("CameraVC.cleanup")
    
    let notificationCenter = NSNotificationCenter.defaultCenter()
    notificationCenter.removeObserver(self, name: UIDeviceOrientationDidChangeNotification, object: nil)
    notificationCenter.removeObserver(self, name: UIApplicationDidBecomeActiveNotification, object: UIApplication.sharedApplication())
    notificationCenter.removeObserver(self, name: UIApplicationWillResignActiveNotification, object: UIApplication.sharedApplication())

    
    // Stop and tear down the capture session
    captureManager?.stopAndTearDownCaptureSession()
    captureManager?.delegate = nil
    
    //Stop update time and speed timer
    stopTimer(&updateTimeTimer)
    stopTimer(&updateLocationTimer)
    stopTimer(&removeControlViewTimer)
  }
  
  func applicationDidBecomeActive(notification: NSNotification) {
    //print("CameraVC.applicationDidBecomeActive")
    // For performance reasons, we manually pause/resume the session when saving a recording.
    // If we try to resume the session in the background it will fail. Resume the session here as well to ensure we will succeed.
    captureManager?.resumeCaptureSession()
    
    if mustRecord {
      captureManager?.startRecording()
    }
  }
  
  func applicationWillResignActive(notification: NSNotification) {
    //print("CameraVC.applicationWillResignActive")
    if let cm = captureManager {
      if cm.recording {
          cm.stopRecording()
      }
    }
  }

  
  
  
  func deviceOrientationDidChange() {
    //print("CameraVC.deviceOrientationDidChange")
    
    let orientation = UIDevice.currentDevice().orientation
    
    //print("DEVICE ORIENTATION: \(orientation.rawValue)")
    
    if let cm = captureManager {
      if !cm.recording {
        var angle: CGFloat = 0.0
        
        switch orientation {
        case UIDeviceOrientation.LandscapeLeft:
          angle = CGFloat(-M_PI_2)
        case UIDeviceOrientation.LandscapeRight:
          angle = CGFloat(M_PI_2)
        case UIDeviceOrientation.PortraitUpsideDown:
          angle = CGFloat(M_PI)
        case UIDeviceOrientation.Portrait:
          angle = 0.0
        default :
          return
        }
        
        if let layer = layer {
          layer.transform = CATransform3DIdentity
          layer.transform = CATransform3DMakeRotation(angle, 0, 0, 1)
          layer.frame = previewView.frame
        }
        
        if let captureOrient = transitionCaptureOrientationFromDeviceOrientation(orientation) {
          cm.referenceOrientation = captureOrient
        }
      }
    }
  }
  
  
  
  //MARK: - IBActions
  
  @IBAction func toggleRecording(sender: UIButton) {
    //print("CameraVC.toggleRecording")
    // Wait for the recording to start/stop before re-enabling the record button.
    recordButton.enabled = false
    if let cm = captureManager {
      if cm.recording {
        // The recordingWill/DidStop delegate methods will fire asynchronously in response to this call
        cm.stopRecording()
        mustRecord = false
      } else {
        // The recordingWill/DidStart delegate methods will fire asynchronously in response to this call
        cm.startRecording()
        mustRecord = true
      }
    }
  }
  
  func stopRecordigByTimer() {
    if let cm = captureManager {
      if cm.recording {
        // The recordingWill/DidStop delegate methods will fire asynchronously in response to this call
        resetRecordingTimer = true
        cm.stopRecording()
      }
    }
  }
  
  func checkFilesStopRecordingDueSpaceLimit() {
    if assetItemsList.count <= 1 {
      drawControlView()
      recordButton.enabled = false
      if let cm = captureManager {
        if cm.recording {
          // The recordingWill/DidStop delegate methods will fire asynchronously in response to this call
          cm.stopRecording()
          mustRecord = false
        }
      }
      let alert = UIAlertController(
        title: NSLocalizedString("No Disk Space", comment: "CameraVC Error-Title: No Disk Space"),
        message: NSLocalizedString("Please, Clear Storage", comment: "CameraVC Error-Message: Please, Clear Storage"),
        preferredStyle: .Alert)
      let cancelAction = UIAlertAction(title: "OK", style: .Default) { (action: UIAlertAction!) -> Void in
        
      }
      alert.addAction(cancelAction)
      presentViewController(alert, animated: true, completion: nil)
    } else {
      let asset = assetItemsList[0]
      removeFile(asset.url)
      assetItemsList.removeAtIndex(0)
    }
  }
  
  func checkMaxNumberFiles() {
    
    while assetItemsList.count > settings.maxNumberFiles {
      let asset = assetItemsList[0]
      removeFile(asset.url)
      assetItemsList.removeAtIndex(0)
    }
    
  }
  
  /*
  @IBAction func toggQualityMode(sender: UISegmentedControl) {
    print("CameraVC.toggQualityMode")
    setSessionPresetAndSelectedQuality(QualityMode(rawValue: sender.selectedSegmentIndex)!)
    
    NSUserDefaults.standardUserDefaults().setValue(qualityModeSegment.selectedSegmentIndex, forKey: SelectedSegmentKey)
    NSUserDefaults.standardUserDefaults().synchronize()
  }
  */
  
  @IBAction func changeOpacity(sender: UISlider) {
    layer?.opacity = sender.value
    
    NSUserDefaults.standardUserDefaults().setValue(sender.value, forKey: LayerOpacityValueKey)
    NSUserDefaults.standardUserDefaults().synchronize()
    
    if let capture = captureManager {
      if capture.recording && removeControlViewTimer != nil {
        resetControlViewTimer()
      }
    }
  }
  
  @IBAction func tapGesture(sender: UITapGestureRecognizer) {
    //print("TAP")
    if let cm = captureManager {
      if cm.recording {
        if controlViewConstraint.constant != 0 {
          drawControlView()
        } else {
          resetControlViewTimer()
        }
      }
    }
  }
  
}

//MARK: - CaptureManagerDelegate

extension CameraViewController : CaptureManagerDelegate {
  
  func recordingWillStart() {
    //print("CameraVC.recordingWillStart")
    dispatch_async(dispatch_get_main_queue()) { () -> Void in
      self.recordButton.enabled = false
      self.settingsButton.enabled = false
      self.backButton.enabled = false
      self.recordButton.setImage(UIImage(named: "StartHighlight"), forState: .Normal)
      
      // Disable the idle timer while we are recording
      UIApplication.sharedApplication().idleTimerDisabled = true
      
      // Make sure we have time to finish saving the movie if the app is backgrounded during recording
      if UIDevice.currentDevice().multitaskingSupported {
        self.backgroundRecordingID = UIApplication.sharedApplication().beginBackgroundTaskWithExpirationHandler({})
      }
    }
  }
  
  func recordingDidStart() {
    //print("CameraVC.recordingDidStart")
    dispatch_async(dispatch_get_main_queue()) { () -> Void in
      self.recordingTimer = NSTimer.scheduledTimerWithTimeInterval(Double(self.settings.maxRecordingTime * 60), target: self, selector: Selector("stopRecordigByTimer"), userInfo: nil, repeats: false)
      
      
      // Enable the stop button now that the recording has started
      self.recordButton.enabled = true
      self.recordButton.setImage(UIImage(named: "StopNormal"), forState: .Normal)
      self.resetControlViewTimer()
      self.speedView.hidden = false
      self.speedLabelNoData()
    }
  }
  
  func recordingWillStop() {
    //print("CameraVC.recordingWillStop")
    dispatch_async(dispatch_get_main_queue()) { () -> Void in
      // Disable until saving to the camera roll is complete
      
      self.recordButton.enabled = false
      self.recordButton.setImage(UIImage(named: "StopHighlight"), forState: .Normal)
      self.unitsSpeedLabel.text = ""
      self.speedLabel.text = NSLocalizedString("Stop", comment: "CameraVC: Stop")
      // Pause the capture session so that saving will be as fast as possible.
      // We resume the sesssion in recordingDidStop:
      self.captureManager?.pauseCaptureSession()
      self.stopTimer(&self.removeControlViewTimer)
      self.stopTimer(&self.updateLocationTimer)
      
      self.odometer.stop()
    }
  }
  
  func recordingDidStop() {
    //print("CameraVC.recordingDidStop")
    dispatch_async(dispatch_get_main_queue()) { () -> Void in
     
        // Enable record and update mode buttons
        self.updateBatteryAndDiskLabels()
        self.recordButton.enabled = true
        self.recordButton.setImage(UIImage(named: "StartNormal"), forState: .Normal)
        self.settingsButton.enabled = true
        self.backButton.enabled = true
        
        self.speedLabel.text = ""
        self.speedView.hidden = true
        
        UIApplication.sharedApplication().idleTimerDisabled = false
        // for previewLayer
        self.captureManager?.resumeCaptureSession()
        
        if UIDevice.currentDevice().multitaskingSupported {
          UIApplication.sharedApplication().endBackgroundTask(self.backgroundRecordingID)
          self.backgroundRecordingID = UIBackgroundTaskInvalid
        }
      
      if self.resetRecordingTimer {
        self.resetRecordingTimer = false
        if let cm = self.captureManager {
          cm.startRecording()
        }
      }
      
      self.createMovieContents()
      self.checkMaxNumberFiles()
    }
  }
  
  func newLocationUpdate(speed: String) {
    //print("CameraVC.newLocationUpdate")
    // Use this method to update the label which indicates the current speed
    
    let words = speed.componentsSeparatedByString(" ")
    if words.count == 2 {
      speedLabel.text = words[0]
      unitsSpeedLabel.text = words[1]
    }
    
    resetLocationTimer()
  }
  
  func distanceUpdate(location: CLLocation) {
    if let distance = odometer.distanceUpdate(location) {
      createOdometerLabel(distance)
      settings.odometerMeters = distance
    }
  }
  
  func createOdometerLabel(distance: Int) {
    if settings.typeSpeed == .Km {
      odometerLabel.text = String(format: "%06.1f", Float(distance)/1000.0)
    } else {
      odometerLabel.text = String(format: "%06.1f", Float(distance)/1609.344)
    }
  }
  
  func showError(error: NSError) {
    //print("CameraVC.showError")
    //print("_ERROR_: \(error), \(error.userInfo)")
    
    let alert = UIAlertController(title: error.localizedDescription, message: error.localizedFailureReason, preferredStyle: .Alert)
    let cancelAction = UIAlertAction(title: "OK", style: .Default) { (action: UIAlertAction!) -> Void in
      exit(0)
    }
    alert.addAction(cancelAction)
    presentViewController(alert, animated: true, completion: nil)
  }
  
  //MARK: - Utilites
  
  func setResolutionAndTextLabels() {
    if settings.textOnVideo {
      textLabel.text = NSLocalizedString("Text", comment: "CameraVC textLabel: Text")
      textLabel.hidden = false
    } else {
      textLabel.text = ""
      textLabel.hidden = true
    }
    
    if settings.qualityMode == .High {
      resolutionLabel.text = "720p"
    } else if settings.qualityMode == .Medium {
      resolutionLabel.text = "480p"
    } else {
      resolutionLabel.text = "288p"
    }
  }
  
  func timeLabelUpdate() {
    //print("CameraVC.timeUpdate")
    let dateFormater = NSDateFormatter()
    dateFormater.dateFormat = "yyyy/MM/dd HH:mm:ss"
    let timeString = dateFormater.stringFromDate(NSDate())
    timeLabel.text = timeString
    captureManager?.time = timeString
    
    if let cm = captureManager {
      frameRateLabel.text = String(format: "%.1f", cm.frc.frameRate)
      if cm.frc.frameRate < 13 {
        frameRateLabel.textColor = UIColor.redColor()
      } else if cm.frc.frameRate < 24 {
        frameRateLabel.textColor = UIColor.yellowColor()
      } else {
        frameRateLabel.textColor = UIColor.greenColor()
      }
    }
  }
  
  // Reset timer update location after receive newLocation
  func resetLocationTimer() {
    //print("CameraVC.resetLocationTimer")
    stopTimer(&updateLocationTimer)
    if updateLocationTimer == nil {
      updateLocationTimer = NSTimer.scheduledTimerWithTimeInterval(kUpdateLocationInterval, target: self, selector: Selector("speedLabelNoData"), userInfo: nil, repeats: true)
    }
  }
  
  func resetControlViewTimer() {
    //print("CameraVC.resetControlViewTimer")
    stopTimer(&removeControlViewTimer)
    if removeControlViewTimer == nil {
      removeControlViewTimer = NSTimer.scheduledTimerWithTimeInterval(kRemoveControlViewInterval, target: self, selector: Selector("removeControlView"), userInfo: nil, repeats: false)
    }
  }
  
  func stopTimer(inout timer: NSTimer?) {
    //print("CameraVC.stopTimer")
    if timer != nil {
      timer!.invalidate()
      timer = nil
    }
  }
  
  func speedLabelNoData() {
    //print("CameraVC.speedUpdate")
    let strNoData = NSLocalizedString("NoData", comment: "CameraVC: No data")
    speedLabel.text = strNoData
    unitsSpeedLabel.text = ""
    captureManager?.speed = strNoData
  }
  
  func updateBatteryAndDiskLabels() {
    
    let device = UIDevice.currentDevice()
    device.batteryMonitoringEnabled = true
    let barLeft = device.batteryLevel
    device.batteryMonitoringEnabled = false
    let batteryLevel = Int(barLeft*100)
    batteryLabel.text = "\(batteryLevel)"
    if batteryLevel > 80 {
      batteryLabel.textColor = UIColor.greenColor()
    } else if batteryLevel > 20 {
      batteryLabel.textColor = UIColor.yellowColor()
    } else {
      batteryLabel.textColor = UIColor.redColor()
    }
    
    if let bytes = deviceRemainingFreeSpaceInBytes() {
      let hMBytes = Int(bytes/10_0000_000)
      freeSpace = Float(hMBytes)/10
      fillDiskLabel.text = "\(freeSpace)"
      if freeSpace < 1 {
        fillDiskLabel.textColor = UIColor.redColor()
      } else if freeSpace < 5 {
        fillDiskLabel.textColor = UIColor.yellowColor()
      } else {
        fillDiskLabel.textColor = UIColor.greenColor()
      }
      if mustRecord && freeSpace < 0.3 {
        checkFilesStopRecordingDueSpaceLimit()
      }
    }
  }
  
  func deviceRemainingFreeSpaceInBytes() -> Int64? {
    let documentDirectoryPath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
    let defaultManager = NSFileManager.defaultManager()
    do {
      let systemAttributes = try defaultManager.attributesOfFileSystemForPath((documentDirectoryPath.last as String?)!)
      let freeSize = (systemAttributes[NSFileSystemFreeSize] as? NSNumber)?.longLongValue
      return freeSize
    } catch {
      return nil
    }
  }
  
  func removeControlView() {
    //print("CameraVC.removeControlView")
    controlViewConstraint.constant = -80.0
    UIView.animateWithDuration(0.5) { () -> Void in
      self.view.layoutIfNeeded()
    }
    stopTimer(&removeControlViewTimer)
  }
  
  func drawControlView() {
    //print("CameraVC.drawControlView")
    controlViewConstraint.constant = 0
    UIView.animateWithDuration(0.5) { () -> Void in
      self.view.layoutIfNeeded()
    }
    resetControlViewTimer()
  }
  
  func transitionCaptureOrientationFromDeviceOrientation(orientation: UIDeviceOrientation) -> AVCaptureVideoOrientation? {
    //print("CameraVC.transitionCaptureOrientationFromDeviceOrientation")
    
    switch orientation {
    case .LandscapeLeft:
      return .LandscapeRight
    case .LandscapeRight:
      return .LandscapeLeft
    case .PortraitUpsideDown:
      return .PortraitUpsideDown
    case .Portrait:
      return .Portrait
    default:
      return nil
    }
  }
  
  func setupPreviewLayer() {
    if let session = captureManager?.captureSession {
      
      setSessionPresetAndSelectedQuality(settings.qualityMode)
      
      let orientation = UIDevice.currentDevice().orientation
      var angle: CGFloat = 0.0
      
      switch orientation {
      case UIDeviceOrientation.LandscapeLeft:
        angle = CGFloat(-M_PI_2)
      case UIDeviceOrientation.LandscapeRight:
        angle = CGFloat(M_PI_2)
      case UIDeviceOrientation.PortraitUpsideDown:
        angle = CGFloat(M_PI)
      default :
        angle = 0.0
      }
      
      if let captureOrient = transitionCaptureOrientationFromDeviceOrientation(orientation) {
        captureManager?.referenceOrientation = captureOrient
      }
      if layer == nil {
        layer = AVCaptureVideoPreviewLayer(session: session)
      }
      if let layer = self.layer {
        //A string defining how the video is displayed within an AVCaptureVideoPreviewLayer bounds rect.
        layer.videoGravity = AVLayerVideoGravityResizeAspect
        
        if let storedOpacity = NSUserDefaults.standardUserDefaults().valueForKey(LayerOpacityValueKey)?.floatValue {
          layer.opacity = storedOpacity
          layerOpacitySlider.value = storedOpacity
        }
        layer.transform = CATransform3DIdentity
        layer.transform = CATransform3DMakeRotation(angle, 0, 0, 1)
        layer.frame = previewView.frame
        
        previewView.layer.addSublayer(layer)
      }
    }
  }
  
  func setSessionPresetAndSelectedQuality(value: QualityMode) {
    if let session = captureManager?.captureSession {
      switch value {
      case .High:
        if session.canSetSessionPreset(AVCaptureSessionPreset1280x720) && settings.typeCamera == .Back {
          session.sessionPreset = AVCaptureSessionPreset1280x720
          captureManager?.scaleText = 2
          settings.qualityMode = .High
        } else if session.canSetSessionPreset(AVCaptureSessionPreset640x480) {
          session.sessionPreset = AVCaptureSessionPreset640x480
          captureManager?.scaleText = 1
          settings.qualityMode = .Medium
        } else {
          session.sessionPreset = AVCaptureSessionPresetLow
          captureManager?.scaleText = 0
          settings.qualityMode = .Low
        }
      case .Medium:
        if session.canSetSessionPreset(AVCaptureSessionPreset640x480) {
          session.sessionPreset = AVCaptureSessionPreset640x480
          captureManager?.scaleText = 1
          settings.qualityMode = .Medium
        } else {
          session.sessionPreset = AVCaptureSessionPresetLow
          captureManager?.scaleText = 0
          settings.qualityMode = .Low
        }
      case .Low:
        session.sessionPreset = AVCaptureSessionPresetLow
        captureManager?.scaleText = 0
        settings.qualityMode = .Low
      }
      NSUserDefaults.standardUserDefaults().setValue(settings.qualityMode.rawValue, forKey: QualityModeKey)
      NSUserDefaults.standardUserDefaults().synchronize()
    }
  }
  
  func treatPhoneCall(call: CTCall) {
    //print("CALL: \(call.callState)")
    if let cm = captureManager {
      if cm.recording {
        if call.callState == CTCallStateIncoming {
          cm.stopRecording()
        }
      }
      if mustRecord {
        if call.callState == CTCallStateDisconnected {
          cm.startRecording()
        }
      }
    }
  }
  
  func loadSettings() {
    
    if let storedQuality = NSUserDefaults.standardUserDefaults().valueForKey(QualityModeKey)?.integerValue {
      settings.qualityMode = QualityMode(rawValue: storedQuality)!
    }
    
    if let storedTypeCamera = NSUserDefaults.standardUserDefaults().valueForKey(TypeCameraKey)?.integerValue {
      settings.typeCamera = TypeCamera(rawValue: storedTypeCamera)!
    }

    if let storedAutofocusing = NSUserDefaults.standardUserDefaults().valueForKey(AutofocusingKey)?.boolValue {
      settings.autofocusing = storedAutofocusing
    }
    
    if let storedTextOnVideo = NSUserDefaults.standardUserDefaults().valueForKey(TextOnVideoKey)?.boolValue {
      settings.textOnVideo = storedTextOnVideo
    }
    
    if let storedLogotype = NSUserDefaults.standardUserDefaults().objectForKey(LogotypeKey) {
      settings.logotype = storedLogotype as! String
    }
    
    if let storedMinIntervalLocations = NSUserDefaults.standardUserDefaults().valueForKey(MinIntervalLocationsKey)?.integerValue {
      settings.minIntervalLocations = storedMinIntervalLocations
    }
    
    if let storedTypeSpeed = NSUserDefaults.standardUserDefaults().valueForKey(TypeSpeedKey)?.integerValue {
      settings.typeSpeed = TypeSpeed(rawValue: storedTypeSpeed)!
    }
    
    if let storeMaxRecordingTime = NSUserDefaults.standardUserDefaults().valueForKey(MaxRecordingTimeKey)?.integerValue {
      settings.maxRecordingTime = storeMaxRecordingTime
    }
    
    if let storedMaxNumberFiles = NSUserDefaults.standardUserDefaults().valueForKey(MaxNumberFilesKey)?.integerValue {
      settings.maxNumberFiles = storedMaxNumberFiles
    }
    
    if let storedOdometerMeters = NSUserDefaults.standardUserDefaults().valueForKey(OdometerMetersKey)?.integerValue {
      settings.odometerMeters = storedOdometerMeters
    }

  }
  
  func saveSettings() {
    captureManager?.typeCamera = settings.typeCamera
    captureManager?.minInterval = settings.minIntervalLocations
    captureManager?.typeSpeed = settings.typeSpeed
    captureManager?.autofocusing = settings.autofocusing
    captureManager?.logotype = settings.logotype
    captureManager?.textOnVideo = settings.textOnVideo
    
    if settings.odometerMeters == 0 {
      odometer.reset()
    }
    
    checkMaxNumberFiles()
    
    NSUserDefaults.standardUserDefaults().setValue(settings.qualityMode.rawValue, forKey: QualityModeKey)
    NSUserDefaults.standardUserDefaults().setValue(settings.typeCamera.rawValue, forKey: TypeCameraKey)
    NSUserDefaults.standardUserDefaults().setValue(settings.autofocusing, forKey: AutofocusingKey)
    NSUserDefaults.standardUserDefaults().setValue(settings.minIntervalLocations, forKey: MinIntervalLocationsKey)
    NSUserDefaults.standardUserDefaults().setValue(settings.typeSpeed.rawValue, forKey: TypeSpeedKey)
    NSUserDefaults.standardUserDefaults().setValue(settings.maxRecordingTime, forKey: MaxRecordingTimeKey)
    NSUserDefaults.standardUserDefaults().setValue(settings.maxNumberFiles, forKey: MaxNumberFilesKey)
    NSUserDefaults.standardUserDefaults().setValue(settings.textOnVideo, forKey: TextOnVideoKey)
    NSUserDefaults.standardUserDefaults().setObject(settings.logotype, forKey: LogotypeKey)
    
    NSUserDefaults.standardUserDefaults().synchronize()
  }
  
  func createMovieContents() {
    //print("AssetsVC.createMovieContents")
    assetItemsList = [AssetItem]()
    
    let fileManager = NSFileManager.defaultManager()
    
    do {
      let list = try fileManager.contentsOfDirectoryAtPath(NSTemporaryDirectory())
      for item in list {
        if item.hasSuffix(".mov") {
          
          let asset = AssetItem(title: item)
          assetItemsList.append(asset)
          //print("ASSETS_COUNT: \(assetItemsList.count)")
        }
      }
    } catch {
      //print("ERROR: AssetsVC.createMovieContents")
      let nserror = error as NSError
      NSLog("MoviesURL error: \(nserror), \(nserror.userInfo)")
    }
  }
  
  func removeFile(fileURL: NSURL) {
    //print("CameraVC.removeFile")
    
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

  
  
  // MARK: - Navigation
  
  override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
    if segue.identifier == "settingsSegue" {
      if let destVC = segue.destinationViewController as? UINavigationController {
        if let settingsVC = destVC.viewControllers.first as? SettingsViewController {
          settingsVC.settings = settings
          settingsVC.numberAssetFiles = assetItemsList.count
          settingsVC.delegate = self
        }
      }
    }
    
    if segue.identifier == "assetsSegue" {
      if let destVC = segue.destinationViewController as? AssetsViewController {
        destVC.assetItemsList = assetItemsList
        destVC.freeSpace = freeSpace
        destVC.typeSpeed = settings.typeSpeed
        if !IAPHelper.iapHelper.setRemoveAd {
          destVC.interstitialPresentationPolicy = .Manual
        }
      }
    }
  }
  
}

