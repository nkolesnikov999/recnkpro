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
import Speech
import StoreKit

let OtherTimeKey = "OtherTimeKey"
let FrontQualityModeKey = "FrontQualityModeKey"
let BackQualityModeKey = "BackQualityModeKey"
let TypeCameraKey = "TypeCameraKey"
let AutofocusingKey = "AutofocusingKey"
let MinIntervalLocationsKey = "MinIntervalLocationsKey"
let TypeSpeedKey = "TypeSpeedKey"
let MaxRecordingTimeKey = "MaxRecordingTimeKey"
let MaxNumberVideoKey = "MaxNumberVideoKey"
let IntevalPictureKey = "IntevalPictureKey"
let LayerOpacityValueKey = "LayerOpacityValueKey"
let OdometerMetersKey = "OdometerMetersKey"
let TextOnVideoKey = "TextOnVideoKey"
let LogotypeKey = "LogotypeKey"
let MicOnKey = "MicOnKey"
let maxNumberPictures = 5


class CameraViewController : UIViewController, SettingsControllerDelegate {
  
  var settings = Settings()
  var layer: AVCaptureVideoPreviewLayer?
  var captureManager: CaptureManager?
  var backgroundRecordingID: UIBackgroundTaskIdentifier = UIBackgroundTaskInvalid
  var mustRecord = false
  var resetRecordingTimer = false
  var changingCamera = false
  var isPhotoImage = false
  var isLock = false
  var freeSpace: Float = 0
  
  var recordingTimer: Timer?
  var photoTimer: Timer?
  var updateTimeTimer: Timer?
  var updateLocationTimer: Timer?
  var updateBatteryAndDiskTimer: Timer?
  var removeControlViewTimer: Timer?
  
  var callCenter: CTCallCenter!
  var assetItemsList: [AssetItem]!
  var picturesCount: Int = 0
  var odometer: Odometer!
  var lastLocation: CLLocation?
  
  let kUpdateTimeInterval: TimeInterval = 1.0
  let kUpdateLocationInterval: TimeInterval = 3.0
  let kUpdateBatteryAndDiskInterval: TimeInterval = 30.0
  let kRemoveControlViewInterval: TimeInterval = 10.0
  
  let titleAlert = NSLocalizedString("Message", comment: "SettingVC Error-Title")
  let messageAlert = NSLocalizedString("For more pictures you need to buy Full Version\n", comment: "CameraVC Alert-Message")
  let lockAlert = NSLocalizedString("For running this function you need to buy Full Version\n", comment: "SettingVC Error-Message")
  
  let audioEngine = AVAudioEngine()
  let speechRecognizer = SFSpeechRecognizer(locale: Locale.current)
  var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
  var recognitionTask: SFSpeechRecognitionTask?
  var mostRecentlyProcessedSegmentDuration: TimeInterval = 0
  
  let synth = AVSpeechSynthesizer()
  
  var iconsImage: UIImage? {
    didSet {
      var tmpImage: UIImage?
      if !isPhotoImage {
        tmpImage = backButton.image(for: UIControlState())
        isPhotoImage = true
      }
      
      if let image = iconsImage {
        backButton.setImage(image, for: UIControlState())
        delay(4) {
          self.backButton.setImage(tmpImage, for: UIControlState())
          self.isPhotoImage = false
        }
      } else {
        backButton.setImage(tmpImage, for: UIControlState())
      }
    }
  }
  
  var picture: Picture? {
    didSet {
      if let picture = picture {
        PicturesList.pList.pictures.append(picture)
        PicturesList.pList.pictures.sort(by: { $0.date.compare($1.date as Date) == ComparisonResult.orderedDescending })
        PicturesList.pList.savePictures()
        picturesCount = PicturesList.pList.pictures.count
      }
    }
  }
  
  func delay(_ time: Double, completionBlock: @escaping () -> ()) {
    let dispatchTime = DispatchTime.now() + Double(Int64(Double(NSEC_PER_SEC) * time)) / Double(NSEC_PER_SEC)
    DispatchQueue.main.asyncAfter(deadline: dispatchTime) {
      completionBlock()
    }
  }
  
  
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
  @IBOutlet weak var micButton: UIButton!
  @IBOutlet weak var textLabel: UILabel!
  @IBOutlet weak var backButton: UIButton!
  @IBOutlet weak var fillDiskLabel: UILabel!
  @IBOutlet weak var batteryLabel: UILabel!
  @IBOutlet weak var controlViewConstraint: NSLayoutConstraint!
  @IBOutlet weak var lockButton: UIButton!
  
  @IBOutlet weak var flashView: UIView!
  @IBOutlet weak var photoView: UIImageView!
  @IBOutlet weak var transcriptionOutputLabel: UILabel!

  //MARK: - View Loading
  
  class func deviceRemainingFreeSpaceInBytes() -> Int64? {
    let documentDirectoryPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
    let defaultManager = FileManager.default
    do {
      let systemAttributes = try defaultManager.attributesOfFileSystem(forPath: (documentDirectoryPath.last as String?)!)
      let freeSize = (systemAttributes[FileAttributeKey.systemFreeSize] as? NSNumber)?.int64Value
      return freeSize
    } catch {
      return nil
    }
  }
  
  override func viewDidLoad() {
    //print("CameraVC.viewDidLoad")
    super.viewDidLoad()
    
    resolutionLabel.layer.backgroundColor = UIColor(red: 176.0/255.0, green: 176.0/255.0, blue: 176.0/255.0, alpha: 0.5).cgColor
    resolutionLabel.layer.cornerRadius = 10.0
    
    textLabel.layer.backgroundColor = UIColor(red: 176.0/255.0, green: 176.0/255.0, blue: 176.0/255.0, alpha: 0.5).cgColor
    textLabel.layer.cornerRadius = 10.0
    
    timeLabel.layer.backgroundColor = UIColor(red: 176.0/255.0, green: 176.0/255.0, blue: 176.0/255.0, alpha: 0.5).cgColor
    timeLabel.layer.cornerRadius = 10.0
    
    odometerLabel.layer.backgroundColor = UIColor(red: 176.0/255.0, green: 176.0/255.0, blue: 176.0/255.0, alpha: 0.5).cgColor
    odometerLabel.layer.cornerRadius = 10.0
    
    transcriptionOutputLabel.layer.backgroundColor = UIColor(red: 176.0/255.0, green: 176.0/255.0, blue: 176.0/255.0, alpha: 0.5).cgColor
    transcriptionOutputLabel.layer.cornerRadius = 10.0
    
    // Keep track of changes to the device orientation so we can update the capture manager
    let notificationCenter = NotificationCenter.default
    notificationCenter.addObserver(self, selector: #selector(CameraViewController.deviceOrientationDidChange), name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
    notificationCenter.addObserver(self, selector: #selector(CameraViewController.applicationDidBecomeActive(_:)), name: NSNotification.Name.UIApplicationDidBecomeActive, object: UIApplication.shared)
    notificationCenter.addObserver(self, selector: #selector(CameraViewController.applicationWillResignActive(_:)), name: NSNotification.Name.UIApplicationWillResignActive, object: UIApplication.shared)
    notificationCenter.addObserver(self, selector: #selector(CameraViewController.handlePurchaseNotification(_:)), name: NSNotification.Name(rawValue: IAPHelper.IAPHelperPurchaseNotification), object: nil)
    
    UIDevice.current.beginGeneratingDeviceOrientationNotifications()
    
    // Load settings if they are not we'll use defaults that was define in Settings
    loadSettings()
    
    callCenter = CTCallCenter()
    callCenter.callEventHandler = { (call: CTCall) in
      self.treatPhoneCall(call)
    }
    
    speedLabelNoData()
    speedView.isHidden = false
    
    //timeLabel.text = "2016/01/01 00:00:00"
    //batteryLabel.text = "80"
    //fillDiskLabel.text = "0.0"
    
    //frameRateLabel.text = "0.0"
    frameRateLabel.textColor = UIColor.red

    recordButton.setImage(UIImage(named: "StartNormal"), for: UIControlState())
    micButton.setImage(UIImage(named: settings.isMicOn ? "Mic" : "NoMic"), for: UIControlState())

    //controlView.hidden = true
    
    // Initialize the class responsible for managing AV capture session and asset writer
    captureManager = CaptureManager()
    
    if let captureManager = captureManager {
    
      captureManager.delegate = self
      captureManager.minInterval = settings.minIntervalLocations
      captureManager.typeSpeed = settings.typeSpeed
      captureManager.autofocusing = settings.autofocusing
      captureManager.typeCamera = settings.typeCamera
      captureManager.logotype = settings.logotype
      captureManager.textOnVideo = settings.textOnVideo
      captureManager.isMicOn = settings.isMicOn
      
      // Setup and start the capture session
      captureManager.setupAndStartCaptureSession()
    } else {
      print("CaptureManager didn't create!")
    }
    
    odometer = Odometer(distance: settings.odometerMeters)
    createOdometerLabel(settings.odometerMeters)
    
    setResolutionAndTextLabels()
    
    let photoLongRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(CameraViewController.photoLong(_:)))
    photoLongRecognizer.minimumPressDuration = 2.0
    self.photoView.addGestureRecognizer(photoLongRecognizer)
    
    let photoTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(CameraViewController.photoTap(_:)))
    self.photoView.addGestureRecognizer(photoTapRecognizer)
  }
  

  
  override func viewDidAppear(_ animated: Bool) {
    //print("CameraVC.viewDidAppear")
    super.viewDidAppear(animated)
    
    // Disable the idle timer for CameraVC
    UIApplication.shared.isIdleTimerDisabled = true
    
    createOdometerLabel(settings.odometerMeters)
    timeLabel.text = ""
    
    // Setup preview layer
    setupPreviewLayer()
    
    updateBatteryAndDiskLabels()
    timeLabelUpdate()
    controlViewConstraint.constant = 0
    
    setResolutionAndTextLabels()
    
    // Start update timers label
    updateTimeTimer = Timer.scheduledTimer(timeInterval: kUpdateTimeInterval, target: self, selector: #selector(CameraViewController.timeLabelUpdate), userInfo: nil, repeats: true)
    updateBatteryAndDiskTimer = Timer.scheduledTimer(timeInterval: kUpdateBatteryAndDiskInterval, target: self, selector: #selector(CameraViewController.updateBatteryAndDiskLabels), userInfo: nil, repeats: true)
    removeControlViewTimer = nil
    
    controlView.isHidden = false
    
    createMovieContents()
    picturesCount = PicturesList.pList.pictures.count

    if let captureManager = captureManager {
      captureManager.startUpdatingLocation()
      if !captureManager.isAudioInput {
        micButton.setImage(UIImage(named: "NoMic"), for: UIControlState())
        micButton.isEnabled = false
      }
    } else {
      print("CaptureManager didn't create!")
    }

    initSpeechRecognition()
    if !IAPHelper.iapHelper.setFullVersion {
      requestIAPProducts()
    }
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    //print("CameraVC.viewWillDisappear")
    super.viewWillDisappear(animated)
    
    if let captureManager = captureManager {
      captureManager.stopUpdatingLocation()
    }
    
    photoView.image = UIImage(named: "Camera")
    
    odometer.stop()
    
    UIApplication.shared.isIdleTimerDisabled = false
    
    stopSpeechRecording()
    
    //Stop update timer label
    stopTimer(&updateTimeTimer)
    stopTimer(&updateLocationTimer)
    stopTimer(&removeControlViewTimer)
    stopTimer(&recordingTimer)
    stopTimer(&photoTimer)
  }
  
  deinit {
    //print("CameraVC.deinit")
    cleanup()
  }
  
  override var prefersStatusBarHidden : Bool {
    //print("CameraVC.prefersStatusBarHidden")
    return true
  }
  
  
  override var supportedInterfaceOrientations : UIInterfaceOrientationMask {
    //print("CameraVC.supportedInterfaceOrientations")
    return .all
  }
  
  
  override var shouldAutorotate : Bool {
    //print("CameraVC.shouldAutorotate")
    if let cm = captureManager {
      return !cm.recording
    }
    return true
  }
  
  func cleanup() {
    //print("CameraVC.cleanup")
    
    let notificationCenter = NotificationCenter.default
    notificationCenter.removeObserver(self, name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
    notificationCenter.removeObserver(self, name: NSNotification.Name.UIApplicationDidBecomeActive, object: UIApplication.shared)
    notificationCenter.removeObserver(self, name: NSNotification.Name.UIApplicationWillResignActive, object: UIApplication.shared)
    notificationCenter.removeObserver(self, name: NSNotification.Name(rawValue: IAPHelper.IAPHelperPurchaseNotification), object: nil)
    
    // Stop and tear down the capture session
    captureManager?.stopAndTearDownCaptureSession()
    captureManager?.delegate = nil
    
    //Stop update time and speed timer
    stopTimer(&photoTimer)
    stopTimer(&updateTimeTimer)
    stopTimer(&updateLocationTimer)
    stopTimer(&removeControlViewTimer)
  }
  
  func applicationDidBecomeActive(_ notification: Notification) {
    //print("CameraVC.applicationDidBecomeActive")
    // For performance reasons, we manually pause/resume the session when saving a recording.
    // If we try to resume the session in the background it will fail. Resume the session here as well to ensure we will succeed.
    captureManager?.resumeCaptureSession()
    
    if mustRecord {
      captureManager?.startRecording()
    }
  }
  
  func applicationWillResignActive(_ notification: Notification) {
    //print("CameraVC.applicationWillResignActive")
    if let cm = captureManager {
      if cm.recording {
          cm.stopRecording()
      }
    }
  }

  
  
  
  func deviceOrientationDidChange() {
    //print("CameraVC.deviceOrientationDidChange")
    
    let orientation = UIDevice.current.orientation
    
    //print("DEVICE ORIENTATION: \(orientation.rawValue)")
    
    if let cm = captureManager {
      if !cm.recording {
        var angle: CGFloat = 0.0
        
        switch orientation {
        case UIDeviceOrientation.landscapeLeft:
          angle = CGFloat(-M_PI_2)
        case UIDeviceOrientation.landscapeRight:
          angle = CGFloat(M_PI_2)
        case UIDeviceOrientation.portraitUpsideDown:
          angle = CGFloat(M_PI)
        case UIDeviceOrientation.portrait:
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
  
  @IBAction func toggleRecording(_ sender: UIButton) {
    //print("CameraVC.toggleRecording")
    // Wait for the recording to start/stop before re-enabling the record button.
    recordButton.isEnabled = false
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
  
  func startRecordigByCommand() {
    if let cm = captureManager {
      if !cm.recording {
        cm.startRecording()
        mustRecord = true
      }
    }
  }
  
  func stopRecordigByCommand() {
    if let cm = captureManager {
      if cm.recording {
        if controlViewConstraint.constant != 0 {
          drawControlView()
          resetControlViewTimer()
        }

        cm.stopRecording()
        mustRecord = false
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
    if (assetItemsList.count - LockedList.lockList.lockVideo.count) <= 1 { // <=========
      print("Assets: \(assetItemsList.count), Locked: \(LockedList.lockList.lockVideo.count)")
      drawControlView()
      recordButton.isEnabled = false
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
        preferredStyle: .alert)
      let cancelAction = UIAlertAction(title: "OK", style: .default) { (action: UIAlertAction!) -> Void in
        
      }
      alert.addAction(cancelAction)
      present(alert, animated: true, completion: nil)
    } else {
      var index = assetItemsList.count - 1
      while index >= 1 {
        let asset = assetItemsList[index]
        if !asset.isLocked {
          removeFile(asset.url as URL)
          assetItemsList.remove(at: index)
          break
        }
        index -= 1
      }
    }
  }
  
  func checkMaxNumberFiles() {
    var index = assetItemsList.count - 1
    while (assetItemsList.count - LockedList.lockList.lockVideo.count) > settings.maxNumberVideo {
      let asset = assetItemsList[index]
      if !asset.isLocked {
        removeFile(asset.url as URL)
        assetItemsList.remove(at: index)
      }
      index -= 1
    }
  }
  
  @IBAction func changeOpacity(_ sender: UISlider) {
    layer?.opacity = sender.value / 10
    
    UserDefaults.standard.setValue(sender.value, forKey: LayerOpacityValueKey)
    UserDefaults.standard.synchronize()
    
    if let capture = captureManager {
      if capture.recording && removeControlViewTimer != nil {
        resetControlViewTimer()
      }
    }
  }
  
  @IBAction func tapGesture(_ sender: UITapGestureRecognizer) {
    // print("TAP")
    if let cm = captureManager {
      if cm.recording {
        if controlViewConstraint.constant != 0 {
          drawControlView()
        } else {
          resetControlViewTimer()
        }
      }
    }
    
    if !audioEngine.isRunning {
      do {
        try self.startSpeechRecording()
      } catch let error {
        print("There was a problem starting recording: \(error.localizedDescription)")
      }
      //recordButton.setTitle("Stop recording", for: [])
    }
  }

  
  func photoLong(_ sender: UITapGestureRecognizer) {
    //print("LONG Tap")
    if sender.state == .began {
      //print("LongTapBegan")
      takeAutoPhoto()
    }
  }
  
  func takeAutoPhoto() {
    if picturesCount < maxNumberPictures || IAPHelper.iapHelper.setFullVersion {
      photoTimer = Timer.scheduledTimer(timeInterval: Double(settings.intervalPictures), target: self, selector: #selector(CameraViewController.takeAutoPhotoByTimer), userInfo: nil, repeats: true)
      self.flashView.alpha = 1
      UIView.animate(withDuration: 0.2, animations: {
        self.flashView.alpha = 0
      })
    }
    takeAutoPhotoByTimer()
  }
  
  func photoTap(_ sender: UITapGestureRecognizer) {
    //print("Photo Tap")
    if sender.state == .ended {
      takePhoto()
    }
  }
  
  func takePhoto() {
    if photoTimer != nil {
      // print("Stop Auto")
      stopTimer(&photoTimer)
    }
    
    if picturesCount >= maxNumberPictures && !IAPHelper.iapHelper.setFullVersion {
      // show alert
      // print("ALERT")
      showAlert(title: titleAlert, message: messageAlert)
    } else {
      self.flashView.alpha = 1
      UIView.animate(withDuration: 0.2, animations: {
        self.flashView.alpha = 0
      })
      photoView.image = UIImage(named: "CameraPhoto")
      delay(0.5) {
        self.photoView.image = UIImage(named: "Camera")
      }
      if let cm = captureManager {
        cm.snapImage()
      }
    }
  }
  
  func takeAutoPhotoByTimer() {
    // print("Photo!")
    if picturesCount >= maxNumberPictures && !IAPHelper.iapHelper.setFullVersion {
      // show alert
      // print("ALERT")
      showAlert(title: titleAlert, message: messageAlert)
      // stop auto
      if photoTimer != nil {
        // print("Stop Auto")
        stopTimer(&photoTimer)
      }
      self.photoView.image = UIImage(named: "Camera")
    } else {
      photoView.image = UIImage(named: "CameraAutoPhoto")
      delay(0.5) {
        self.photoView.image = UIImage(named: "CameraAuto")
      }
      if let cm = captureManager {
        cm.snapImage()
      }
    }
  }

  
  @IBAction func changeCamera() {
    
    //if settings.typeCamera == .back && settings.backQualityMode == .high {
    //  print("ALERT: First Change resolution for back camera")
    //} else {
      if settings.typeCamera == .back {
        settings.typeCamera = .front
      } else {
        settings.typeCamera = .back
      }
      if let cm = captureManager {
        if cm.recording {
          cm.stopRecording()
          changingCamera = true
        }
        cm.typeCamera = settings.typeCamera
      }
      setResolutionAndTextLabels()
      UserDefaults.standard.setValue(settings.typeCamera.rawValue, forKey: TypeCameraKey)
      UserDefaults.standard.synchronize()
    //}
  }
  
  @IBAction func toggleMic(_ sender: UIButton) {
    if settings.isMicOn {
      micButton.setImage(UIImage(named: "NoMic"), for: UIControlState())
      settings.isMicOn = false
      // print("NO MIC")
    } else {
      micButton.setImage(UIImage(named: "Mic"), for: UIControlState())
      settings.isMicOn = true
      // print("MIC")
    }
    if let cm = captureManager {
      cm.isMicOn = settings.isMicOn
    }
    UserDefaults.standard.setValue(settings.isMicOn, forKey: MicOnKey)
    UserDefaults.standard.synchronize()
  }
  
  @IBAction func toggleLockVideo(_ sender: UIButton) {
    if isLock {
      unlockVideo()
    } else {
      lockVideo()
    }
    if let cm = captureManager {
      cm.isLock = isLock
    }
    print(LockedList.lockList.lockVideo)
  }
  
  func lockVideo() {
    if !IAPHelper.iapHelper.setFullVersion {
      // show alert
      // print("ALERT")
      showAlert(title: titleAlert, message: lockAlert)
    }else {
      lockButton.setImage(UIImage(named: "Lock"), for: .normal)
      isLock = true
    }
  }
  
  func unlockVideo() {
    lockButton.setImage(UIImage(named: "UnLock"), for: .normal)
    isLock = false
  }
}

//MARK: - CaptureManagerDelegate

extension CameraViewController : CaptureManagerDelegate {
  
  func recordingWillStart() {
    //print("CameraVC.recordingWillStart")
    DispatchQueue.main.async { () -> Void in
      self.recordButton.isEnabled = false
      self.settingsButton.isEnabled = false
      self.backButton.isEnabled = false
      self.recordButton.setImage(UIImage(named: "StartHighlight"), for: UIControlState())
      self.micButton.isEnabled = false
      
      // Make sure we have time to finish saving the movie if the app is backgrounded during recording
      if UIDevice.current.isMultitaskingSupported {
        self.backgroundRecordingID = UIApplication.shared.beginBackgroundTask(expirationHandler: {})
      }
    }
  }
  
  func recordingDidStart() {
    //print("CameraVC.recordingDidStart")
    DispatchQueue.main.async { () -> Void in
      self.recordingTimer = Timer.scheduledTimer(timeInterval: Double(self.settings.maxRecordingTime) * 60.0, target: self, selector: #selector(CameraViewController.stopRecordigByTimer), userInfo: nil, repeats: false)
      
      
      // Enable the stop button now that the recording has started
      self.recordButton.isEnabled = true
      self.recordButton.setImage(UIImage(named: "StopNormal"), for: UIControlState())
      self.resetControlViewTimer()
    }
  }
  
  func recordingWillStop() {
    //print("CameraVC.recordingWillStop")
    DispatchQueue.main.async { () -> Void in
      // Disable until saving to the camera roll is complete
      
      self.recordButton.isEnabled = false
      self.recordButton.setImage(UIImage(named: "StopHighlight"), for: UIControlState())
      // Pause the capture session so that saving will be as fast as possible.
      // We resume the sesssion in recordingDidStop:
      self.captureManager?.pauseCaptureSession()
      self.stopTimer(&self.removeControlViewTimer)
      
    }
  }
  
  func recordingDidStop() {
    //print("CameraVC.recordingDidStop")
    DispatchQueue.main.async { () -> Void in
     
        // Enable record and update mode buttons
        self.updateBatteryAndDiskLabels()
        self.recordButton.isEnabled = true
        self.recordButton.setImage(UIImage(named: "StartNormal"), for: UIControlState())
        self.settingsButton.isEnabled = true
        self.backButton.isEnabled = true
      
        // for previewLayer
        self.captureManager?.resumeCaptureSession()
        
        if UIDevice.current.isMultitaskingSupported {
          UIApplication.shared.endBackgroundTask(self.backgroundRecordingID)
          self.backgroundRecordingID = UIBackgroundTaskInvalid
        }
      
      if self.resetRecordingTimer {
        self.resetRecordingTimer = false
        if let cm = self.captureManager {
          cm.startRecording()
        }
      }
      
      if self.changingCamera {
        self.changingCamera = false
        if let cm = self.captureManager {
          cm.startRecording()
        }
      }
      
      if let cm = self.captureManager {
        if cm.isAudioInput {
          self.micButton.isEnabled = true
        }
      }
      
      self.createMovieContents()
      self.checkMaxNumberFiles()
    }
  }
  
  func newLocationUpdate(_ speed: String) {
    //print("CameraVC.newLocationUpdate")
    // Use this method to update the label which indicates the current speed
    
    let words = speed.components(separatedBy: " ")
    if words.count == 2 {
      speedLabel.text = words[0]
      unitsSpeedLabel.text = words[1]
    }
    
    resetLocationTimer()
  }
  
  func distanceUpdate(_ location: CLLocation) {
    if let distance = odometer.distanceUpdate(location) {
      createOdometerLabel(distance)
      settings.odometerMeters = distance
    }
    lastLocation = location
  }
  
  func createOdometerLabel(_ distance: Int) {
    if settings.typeSpeed == .km {
      odometerLabel.text = String(format: "%06.1f", Float(distance)/1000.0)
    } else {
      odometerLabel.text = String(format: "%06.1f", Float(distance)/1609.344)
    }
  }
  
  func showError(_ error: NSError) {
    //print("CameraVC.showError")
    //print("_ERROR_: \(error), \(error.userInfo)")
    
    let alert = UIAlertController(title: error.localizedDescription, message: error.localizedFailureReason, preferredStyle: .alert)
    let cancelAction = UIAlertAction(title: "OK", style: .default) { (action: UIAlertAction!) -> Void in
      exit(0)
    }
    alert.addAction(cancelAction)
    present(alert, animated: true, completion: nil)
  }
  
  func showAlert(title: String, message: String) {
    let alert = UIAlertController(title: title, message: message + IAPHelper.iapHelper.price, preferredStyle: .alert)
    
    let buyAction = UIAlertAction(title: NSLocalizedString("Buy", comment: "CameraVC Alert-Buy"), style: .default) { (action: UIAlertAction!) -> Void in
      guard let fullVersionProduct = IAPHelper.iapHelper.fullVersionProduct else { return }
      IAPHelper.iapHelper.buyProduct(fullVersionProduct)
    }

    let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: "CameraVC Alert-Cancel"), style: .cancel) { (action: UIAlertAction!) -> Void in
    }
    if IAPHelper.iapHelper.isSelling {
      alert.addAction(buyAction)
    }
    alert.addAction(cancelAction)
    present(alert, animated: true, completion: nil)
  }
  
  //MARK: - Utilites
  
  func setResolutionAndTextLabels() {
    if settings.textOnVideo {
      textLabel.text = NSLocalizedString("Text", comment: "CameraVC textLabel: Text")
    } else {
      textLabel.text = NSLocalizedString("NT", comment: "CameraVC textLabel: NT")
    }
    
    var mode: QualityMode = .low
    
    if settings.typeCamera == .back {
      mode = settings.backQualityMode
    } else {
      mode = settings.frontQualityMode
    }
    
    if mode == .high {
      resolutionLabel.text = "1080p"
    } else if mode == .medium {
      resolutionLabel.text = "720p"
    } else {
      resolutionLabel.text = "480p"
    }
  }
  
  func timeLabelUpdate() {
    //print("CameraVC.timeUpdate")
    let dateFormater = DateFormatter()
    dateFormater.dateFormat = "yyyy/MM/dd HH:mm:ss"
    let timeString = dateFormater.string(from: Date())
    timeLabel.text = timeString
    captureManager?.time = timeString
    
    if let cm = captureManager {
      frameRateLabel.text = String(format: "%.1f", cm.frc.frameRate)
      if cm.frc.frameRate < 13 {
        frameRateLabel.textColor = UIColor.red
      } else if cm.frc.frameRate < 24 {
        frameRateLabel.textColor = UIColor.yellow
      } else {
        frameRateLabel.textColor = UIColor.green
      }
    }
  }
  
  // Reset timer update location after receive newLocation
  func resetLocationTimer() {
    //print("CameraVC.resetLocationTimer")
    stopTimer(&updateLocationTimer)
    if updateLocationTimer == nil {
      updateLocationTimer = Timer.scheduledTimer(timeInterval: kUpdateLocationInterval, target: self, selector: #selector(CameraViewController.speedLabelNoData), userInfo: nil, repeats: true)
    }
  }
  
  func resetControlViewTimer() {
    //print("CameraVC.resetControlViewTimer")
    stopTimer(&removeControlViewTimer)
    if removeControlViewTimer == nil {
      removeControlViewTimer = Timer.scheduledTimer(timeInterval: kRemoveControlViewInterval, target: self, selector: #selector(CameraViewController.removeControlView), userInfo: nil, repeats: false)
    }
  }
  
  func stopTimer(_ timer: inout Timer?) {
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
    
    let device = UIDevice.current
    device.isBatteryMonitoringEnabled = true
    let barLeft = device.batteryLevel
    device.isBatteryMonitoringEnabled = false
    let batteryLevel = Int(barLeft*100)
    batteryLabel.text = "\(batteryLevel)"
    if batteryLevel > 80 {
      batteryLabel.textColor = UIColor.green
    } else if batteryLevel > 20 {
      batteryLabel.textColor = UIColor.yellow
    } else {
      batteryLabel.textColor = UIColor.red
    }
    
    if let bytes = CameraViewController.deviceRemainingFreeSpaceInBytes() {
      let hMBytes = Int(bytes/10_0000_000)
      freeSpace = Float(hMBytes)/10
      fillDiskLabel.text = "\(freeSpace)"
      if freeSpace < 1 {
        fillDiskLabel.textColor = UIColor.red
      } else if freeSpace < 5 {
        fillDiskLabel.textColor = UIColor.yellow
      } else {
        fillDiskLabel.textColor = UIColor.green
      }
      if mustRecord && freeSpace <= 0.3 {
        checkFilesStopRecordingDueSpaceLimit()
      }
    }
  }
  
  func removeControlView() {
    //print("CameraVC.removeControlView")
    controlViewConstraint.constant = -80.0
    UIView.animate(withDuration: 0.5, animations: { () -> Void in
      self.view.layoutIfNeeded()
    }) 
    stopTimer(&removeControlViewTimer)
  }
  
  func drawControlView() {
    //print("CameraVC.drawControlView")
    controlViewConstraint.constant = 0
    UIView.animate(withDuration: 0.5, animations: { () -> Void in
      self.view.layoutIfNeeded()
    }) 
    resetControlViewTimer()
  }
  
  func transitionCaptureOrientationFromDeviceOrientation(_ orientation: UIDeviceOrientation) -> AVCaptureVideoOrientation? {
    //print("CameraVC.transitionCaptureOrientationFromDeviceOrientation")
    
    switch orientation {
    case .landscapeLeft:
      return .landscapeRight
    case .landscapeRight:
      return .landscapeLeft
    case .portraitUpsideDown:
      return .portraitUpsideDown
    case .portrait:
      return .portrait
    default:
      return nil
    }
  }
  
  func setupPreviewLayer() {
    if let session = captureManager?.captureSession {
        
        setSessionPresetAndSelectedQuality()
        
        let orientation = UIDevice.current.orientation
        var angle: CGFloat = 0.0
        
        switch orientation {
        case UIDeviceOrientation.landscapeLeft:
          angle = CGFloat(-M_PI_2)
        case UIDeviceOrientation.landscapeRight:
          angle = CGFloat(M_PI_2)
        case UIDeviceOrientation.portraitUpsideDown:
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
          layer.videoGravity = AVLayerVideoGravityResizeAspectFill
          
          let storedOpacity = UserDefaults.standard.float(forKey: LayerOpacityValueKey)
          if storedOpacity != 0 {
            layer.opacity = storedOpacity/10
            layerOpacitySlider.value = storedOpacity
          }
          layer.transform = CATransform3DIdentity
          layer.transform = CATransform3DMakeRotation(angle, 0, 0, 1)
          layer.frame = previewView.frame
          
          previewView.layer.addSublayer(layer)
        }
      }
  }
  
  func setSessionPresetAndSelectedQuality() {
    var value: QualityMode = .low
    
    if settings.typeCamera == .back {
      value = settings.backQualityMode
    } else {
      value = settings.frontQualityMode
    }
    
    if let session = captureManager?.captureSession {
      switch value {
      case .high:
        if session.canSetSessionPreset(AVCaptureSessionPreset1920x1080) {
          session.sessionPreset = AVCaptureSessionPreset1920x1080
          captureManager?.scaleText = 2
          value = .high
        } else if session.canSetSessionPreset(AVCaptureSessionPreset1280x720) {
          session.sessionPreset = AVCaptureSessionPreset1280x720
          captureManager?.scaleText = 1
          value = .medium
        } else {
          session.sessionPreset = AVCaptureSessionPreset640x480
          captureManager?.scaleText = 0
          value = .low
        }
      case .medium:
        if session.canSetSessionPreset(AVCaptureSessionPreset1280x720) {
          session.sessionPreset = AVCaptureSessionPreset1280x720
          captureManager?.scaleText = 1
          value = .medium
        } else {
          session.sessionPreset = AVCaptureSessionPreset640x480
          captureManager?.scaleText = 0
          value = .low
        }
      case .low:
        session.sessionPreset = AVCaptureSessionPreset640x480
        captureManager?.scaleText = 0
        value = .low
      }
      
      if settings.typeCamera == .back {
        settings.backQualityMode = value
        UserDefaults.standard.setValue(settings.backQualityMode.rawValue, forKey: BackQualityModeKey)
      } else {
        settings.frontQualityMode = value
        UserDefaults.standard.setValue(settings.frontQualityMode.rawValue, forKey: FrontQualityModeKey)
      }
      
      UserDefaults.standard.synchronize()
    }
  }
  
  func treatPhoneCall(_ call: CTCall) {
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
    
    let isOtherTime = UserDefaults.standard.bool(forKey: OtherTimeKey)
    
    if isOtherTime {
      let frontStoredQuality = UserDefaults.standard.integer(forKey: FrontQualityModeKey)
      if let mode = QualityMode(rawValue: frontStoredQuality) {
        settings.frontQualityMode = mode
      }
      
      let backStoredQuality = UserDefaults.standard.integer(forKey: BackQualityModeKey)
      if let mode = QualityMode(rawValue: backStoredQuality) {
        settings.backQualityMode = mode
      }
      
      let storedTypeCamera = UserDefaults.standard.integer(forKey: TypeCameraKey)
      if let type = TypeCamera(rawValue: storedTypeCamera) {
        settings.typeCamera = type
      }
      
      settings.autofocusing = UserDefaults.standard.bool(forKey: AutofocusingKey)
      settings.textOnVideo = UserDefaults.standard.bool(forKey: TextOnVideoKey)
      
      if let storedLogotype = UserDefaults.standard.string(forKey: LogotypeKey) {
        settings.logotype = storedLogotype
      }
      
      settings.minIntervalLocations = UserDefaults.standard.integer(forKey: MinIntervalLocationsKey)
      
      let storedTypeSpeed = UserDefaults.standard.integer(forKey: TypeSpeedKey)
      if let typeSpeed = TypeSpeed(rawValue: storedTypeSpeed) {
        settings.typeSpeed = typeSpeed
      }
      
      settings.maxRecordingTime = UserDefaults.standard.integer(forKey: MaxRecordingTimeKey)
      settings.maxNumberVideo = UserDefaults.standard.integer(forKey: MaxNumberVideoKey)
      settings.intervalPictures = UserDefaults.standard.integer(forKey: IntevalPictureKey)
      settings.odometerMeters = UserDefaults.standard.integer(forKey: OdometerMetersKey)
      
      settings.isMicOn = UserDefaults.standard.bool(forKey: MicOnKey)
      
    } else {
      
      UserDefaults.standard.set(settings.frontQualityMode.rawValue, forKey: FrontQualityModeKey) //
      UserDefaults.standard.set(settings.backQualityMode.rawValue, forKey: BackQualityModeKey) //
      UserDefaults.standard.set(settings.typeCamera.rawValue, forKey: TypeCameraKey) //
      UserDefaults.standard.set(settings.autofocusing, forKey: AutofocusingKey) //
      UserDefaults.standard.set(settings.minIntervalLocations, forKey: MinIntervalLocationsKey) //
      UserDefaults.standard.set(settings.typeSpeed.rawValue, forKey: TypeSpeedKey) //
      UserDefaults.standard.set(settings.maxRecordingTime, forKey: MaxRecordingTimeKey) //
      UserDefaults.standard.set(settings.maxNumberVideo, forKey: MaxNumberVideoKey) //
      UserDefaults.standard.set(settings.intervalPictures, forKey: IntevalPictureKey) //
      UserDefaults.standard.set(settings.textOnVideo, forKey: TextOnVideoKey) //
      UserDefaults.standard.set(settings.logotype, forKey: LogotypeKey) //
      UserDefaults.standard.set(settings.isMicOn, forKey: MicOnKey)
      UserDefaults.standard.set(true, forKey: OtherTimeKey)
      
      UserDefaults.standard.synchronize()
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
    
    if settings.isMicOn {
      micButton.setImage(UIImage(named: "Mic"), for: UIControlState())
      // print("MIC")
    } else {
      micButton.setImage(UIImage(named: "NoMic"), for: UIControlState())
      // print("NO MIC")
    }
    captureManager?.isMicOn = settings.isMicOn

    
    checkMaxNumberFiles()
    
    UserDefaults.standard.set(settings.frontQualityMode.rawValue, forKey: FrontQualityModeKey)
    UserDefaults.standard.set(settings.backQualityMode.rawValue, forKey: BackQualityModeKey)
    UserDefaults.standard.set(settings.typeCamera.rawValue, forKey: TypeCameraKey)
    UserDefaults.standard.set(settings.autofocusing, forKey: AutofocusingKey)
    UserDefaults.standard.set(settings.minIntervalLocations, forKey: MinIntervalLocationsKey)
    UserDefaults.standard.set(settings.typeSpeed.rawValue, forKey: TypeSpeedKey)
    UserDefaults.standard.set(settings.maxRecordingTime, forKey: MaxRecordingTimeKey)
    UserDefaults.standard.set(settings.maxNumberVideo, forKey: MaxNumberVideoKey)
    UserDefaults.standard.set(settings.intervalPictures, forKey: IntevalPictureKey)
    UserDefaults.standard.set(settings.textOnVideo, forKey: TextOnVideoKey)
    UserDefaults.standard.set(settings.logotype, forKey: LogotypeKey)
    UserDefaults.standard.set(settings.isMicOn, forKey: MicOnKey)
    
    UserDefaults.standard.synchronize()
  }
  
  func createMovieContents() {
    //print("AssetsVC.createMovieContents")
    assetItemsList = [AssetItem]()
    
    let fileManager = FileManager.default
    
    do {
      let list = try fileManager.contentsOfDirectory(atPath: NSTemporaryDirectory())
      for item in list {
        if item.hasSuffix(".mov") {
          
          let asset = AssetItem(title: item)
          assetItemsList.insert(asset, at: 0)
          //print("ASSETS_COUNT: \(assetItemsList.count)")
        }
      }
    } catch {
      //print("ERROR: AssetsVC.createMovieContents")
      let nserror = error as NSError
      NSLog("MoviesURL error: \(nserror), \(nserror.userInfo)")
    }
  }
  
  func removeFile(_ fileURL: URL) {
    //print("CameraVC.removeFile")
    
    let fileManager = FileManager.default
    let filePath = fileURL.path
    if fileManager.fileExists(atPath: filePath) {
      do {
        try fileManager.removeItem(atPath: filePath)
      } catch {
        let nserror = error as NSError
        print("ERROR: AssetsVC.removeFile - \(nserror.userInfo)")
      }
    }
  }

  func synthezeReady() {
    let myUtterance = AVSpeechUtterance(string: "Окей")
    myUtterance.rate = 0.5
    synth.speak(myUtterance)
  }
  
  func synthezeSpeed() {
    let strNodata = NSLocalizedString("NoData", comment: "CameraVC: No data")
    if var strSpeed = speedLabel.text {
      if strSpeed == strNodata {
        strSpeed = "Нет данных"
      }
      let myUtterance = AVSpeechUtterance(string: strSpeed)
      myUtterance.rate = 0.5
      synth.speak(myUtterance)
    }
  }
  
  func synthezeAddress(_ location: CLLocation?) {
    var address = "Не найден"
    guard let location = location else {
      let myUtterance = AVSpeechUtterance(string: address)
      myUtterance.rate = 0.5
      self.synth.speak(myUtterance)
      return
    }
    let geoCoder = CLGeocoder()
    geoCoder.reverseGeocodeLocation(location, completionHandler: { (placemarks, error) -> Void in
      
      if let placemarks = placemarks {
        if placemarks.count > 0 {
          let placemark = placemarks[0]
          
          if let city = placemark.addressDictionary?["City"] as? String {
            address = city
          }
          
          if let locationName = placemark.addressDictionary?["Name"] as? String {
            address = address + "\n" + locationName
          }
        }
      }
      let myUtterance = AVSpeechUtterance(string: address)
      myUtterance.rate = 0.5
      self.synth.speak(myUtterance)
    })
  }

  
  // MARK: - Navigation
  
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if segue.identifier == "settingsSegue" {
      if let destVC = segue.destination as? UINavigationController {
        if let settingsVC = destVC.viewControllers.first as? SettingsViewController {
          settingsVC.settings = settings
          settingsVC.numberAssetFiles = assetItemsList.count
          settingsVC.delegate = self
        }
      }
    }
    
    if segue.identifier == "assetsSegue" {
      if let tabBarController = segue.destination as? UITabBarController {
        if let navVC = tabBarController.viewControllers?[0] as? UINavigationController {
          if let destVC = navVC.viewControllers[0] as? AssetsViewController {
            destVC.assetItemsList = assetItemsList
            destVC.freeSpace = freeSpace
            destVC.typeSpeed = settings.typeSpeed
          }
        }
//        if let navVC = tabBarController.viewControllers?[1] as? UINavigationController {
//          if let destVC = navVC.viewControllers[0] as? PicturesViewController {
//            destVC.picturesList = picturesList
//          }
//        }
      }
    }
  }
}

extension CameraViewController {
  
  fileprivate func initSpeechRecognition() {
    
    speechRecognizer?.delegate = self
    
    SFSpeechRecognizer.requestAuthorization { authStatus in
      /*
       The callback may not be called on the main thread. Add an
       operation to the main queue to update the record button's state.
       */
      DispatchQueue.main.async {
        switch authStatus {
        case .authorized:
          //self.recordButton.isEnabled = true
          self.transcriptionOutputLabel.text = "Hi!"
          do {
            try self.startSpeechRecording()
          } catch let error {
            print("There was a problem starting recording: \(error.localizedDescription)")
          }

        case .denied:
          //self.recordButton.isEnabled = false
          self.transcriptionOutputLabel.text = "User denied access to speech recognition"
          
        case .restricted:
          //self.recordButton.isEnabled = false
          self.transcriptionOutputLabel.text = "Speech recognition restricted on this device"
          
        case .notDetermined:
          //self.recordButton.isEnabled = false
          self.transcriptionOutputLabel.text = "Speech recognition not yet authorized"
        }
      }
    }

  
  }
  
  fileprivate func startSpeechRecording() throws {
    
    mostRecentlyProcessedSegmentDuration = 0
    // Cancel the previous task if it's running.
    if let recognitionTask = recognitionTask {
      recognitionTask.cancel()
      self.recognitionTask = nil
    }
    
    recognitionRequest = SFSpeechAudioBufferRecognitionRequest ()
    
    guard let inputNode = audioEngine.inputNode else {
      print("Audio engine has no input node")
      return
    }
    guard let recognitionRequest = recognitionRequest else {
      print("Unable to created a SFSpeechAudioBufferRecognitionRequest object")
      return
    }
    
    // Configure request so that results are returned before audio recording is finished
    recognitionRequest.shouldReportPartialResults = true
    
    // A recognition task represents a speech recognition session.
    // We keep a reference to the task so that it can be cancelled.
    recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [unowned self] result, error in
      var isFinal = false
      
      if let result = result {
        let transcription = result.bestTranscription
        self.updateUIWithTranscription(transcription)
        isFinal = result.isFinal
      }
      
      if error != nil || isFinal {
        self.audioEngine.stop()
        inputNode.removeTap(onBus: 0)
        
        self.recognitionRequest = nil
        self.recognitionTask = nil
        
        //self.recordButton.isEnabled = true
        self.transcriptionOutputLabel.text = "Tap"
        self.transcriptionOutputLabel.textColor = UIColor.yellow
      }
    }
    
    let recordingFormat = inputNode.outputFormat(forBus: 0)
    inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [unowned self] (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
      self.recognitionRequest?.append(buffer)
    }
    
    audioEngine.prepare()
    
    try audioEngine.start()
    self.transcriptionOutputLabel.text = "Tell"
    self.transcriptionOutputLabel.textColor = UIColor.green
  }
  
  fileprivate func stopSpeechRecording() {
    
    if audioEngine.isRunning {
      audioEngine.stop()
      recognitionRequest?.endAudio()
      
      self.recognitionRequest = nil
      self.recognitionTask = nil
      
      //recordButton.isEnabled = false
      self.transcriptionOutputLabel.text = "Stopping"
      self.transcriptionOutputLabel.textColor = UIColor.yellow
    }
    
  }
  
  
  fileprivate func updateUIWithTranscription(_ transcription: SFTranscription) {
    
    // 2
    if let lastSegment = transcription.segments.last, lastSegment.duration > mostRecentlyProcessedSegmentDuration {
      mostRecentlyProcessedSegmentDuration = lastSegment.duration
      self.transcriptionOutputLabel.text = lastSegment.substring
      self.transcriptionOutputLabel.textColor = UIColor.green
      executeCommand(lastSegment.substring)
    }
  }
  
  fileprivate func executeCommand(_ command: String) {
    let lowCommand = command.lowercased()
    switch lowCommand {
      case "снимок":
        takePhoto()
        synthezeReady()
      case "авто":
        takeAutoPhoto()
        synthezeReady()
      case "запись":
        startRecordigByCommand()
        synthezeReady()
      case "стоп":
        stopRecordigByCommand()
        synthezeReady()
      case "камера":
        changeCamera()
        synthezeReady()
      case "скорость":
        synthezeSpeed()
      case "адрес":
        synthezeAddress(lastLocation)
      case "блокировать":
        lockVideo()
        synthezeReady()
      case "разблокировать":
        unlockVideo()
        synthezeReady()
    default:
      return
    }
  }

}

extension CameraViewController: SFSpeechRecognizerDelegate {
  
  public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
    if available {
      //recordButton.isEnabled = true
      self.transcriptionOutputLabel.text = "Tell"
      self.transcriptionOutputLabel.textColor = UIColor.green
    } else {
      //recordButton.isEnabled = false
      self.transcriptionOutputLabel.text = "Not available"
      self.transcriptionOutputLabel.textColor = UIColor.red
    }
  }
  
}

extension CameraViewController {
  
  func requestIAPProducts() {
    
    IAPHelper.iapHelper.requestProducts {
      products in
      guard let products = products else { return }
      
      if !IAPHelper.iapHelper.setFullVersion {
        IAPHelper.iapHelper.fullVersionProduct = products.filter {
          $0.productIdentifier == RecPurchase.FullVersion.productId
          }.first
      }
      
      if IAPHelper.iapHelper.fullVersionProduct != .none {
        IAPHelper.iapHelper.isSelling = true
        
        let priceFormatter = NumberFormatter()
        priceFormatter.numberStyle = .currency
        priceFormatter.locale = IAPHelper.iapHelper.fullVersionProduct?.priceLocale
        
        if let price = IAPHelper.iapHelper.fullVersionProduct?.price {
          if let strPrice = priceFormatter.string(from: price) {
            IAPHelper.iapHelper.price = strPrice
          }
        }
        
      }
      
      print("FullVersion Product: \(IAPHelper.iapHelper.fullVersionProduct?.productIdentifier), price: \(IAPHelper.iapHelper.price)")
    }
  }
  
  func handlePurchaseNotification(_ notification: Notification) {
    // print(" Camera handlePurchaseNotification")
    if let productID = notification.object as? String {
      
      print("Bought: \(productID)")
      if productID == RecPurchase.FullVersion.productId {
        IAPHelper.iapHelper.setFullVersion = true
        IAPHelper.iapHelper.saveSettings(IAPHelper.FullVersionKey)
      } else {
        print("No such product")
      }
    }
  }
  
}

