//
//  CaptureManager.swift
//  FixDrive
//
//  Created by NK on 17.08.15.
//  Copyright © 2015 Nikolay Kolesnikov. All rights reserved.
//

/*
*  http://stackoverflow.com/questions/21753926/avfoundation-add-text-to-the-cmsamplebufferref-video-frame
*  http://stackoverflow.com/questions/30609241/render-dynamic-text-onto-cvpixelbufferref-while-recording-video
*  http://www.iphones.ru/forum/index.php?showtopic=90033
*  https://github.com/FlexMonkey/MetalVideoCapture
*  http://flexmonkey.blogspot.co.uk/2015/07/generating-filtering-metal-textures.html
*  http://stackoverflow.com/questions/30141940/avfoundation-camera-switches-once-and-only-once
*
*/

import UIKit
import AVFoundation
import CoreLocation
import Photos

let FixdriveSpeedIdentifier = "mdta/net.nkpro.fixdrive.speed.field"
let FixdriveTimeIdentifier = "mdta/net.nkpro.fixdrive.time.field"

protocol CaptureManagerDelegate : class {
  func recordingWillStart()
  func recordingDidStart()
  func recordingWillStop()
  func recordingDidStop()
  func setupPreviewLayer()
  func newLocationUpdate(speed: String)
  func showError(error: NSError)
  func distanceUpdate(location: CLLocation)
}

class CaptureManager : NSObject, AVCaptureAudioDataOutputSampleBufferDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
  
  weak var delegate: CaptureManagerDelegate?
  
  var typeCamera: TypeCamera! {
    didSet {
      changeTypeCamera()
    }
  }
  
  var minInterval: Int! {
    didSet {
      locationManager.distanceFilter = distanceFromInterva(minInterval)
      //print("SET Distance: \(locationManager.distanceFilter)")
    }
  }
  var autofocusing: Bool! {
    didSet {
      setAutofocusing()
    }
  }
  
  var typeSpeed: TypeSpeed!
  
  var scaleText = 0
  var time: String = "" {
    didSet {
      if textOnVideo {
        imageFromText()
      }
    }
  }
  
  var speed: String = "" {
    didSet {
      //imageFromText()
    }
  }
  
  var coordinate: String = "" {
    didSet {
      //imageFromText()
    }
  }
  
  var logotype: String = "NKPRO.NET"
  
  var referenceOrientation: AVCaptureVideoOrientation! {
    didSet {
      //print("SET referenceOrientation: \(referenceOrientation.rawValue)")
    }
  }
  var videoOrientation: AVCaptureVideoOrientation! {
    didSet {
      //print("SET videoOrientation: \(videoOrientation.rawValue)")
    }
  }
  
  var locationManager: CLLocationManager!
  var frc: FrameRateCalculator!
  
  var videoDevice: AVCaptureDevice!
  var videoIn: AVCaptureDeviceInput!
  var videoOut: AVCaptureVideoDataOutput!
  var photoOut: AVCaptureStillImageOutput!
  var captureSession: AVCaptureSession?
  var audioConnection: AVCaptureConnection?
  var videoConnection: AVCaptureConnection?
  var photoConnection: AVCaptureConnection?
  
  var colorSpace: CGColorSpace?
  var ciContext: CIContext!
  var ciInputImage: CIImage!
  
  var movieURL: NSURL!
  var assetWriter: AVAssetWriter?
  var assetWriterAudioIn: AVAssetWriterInput?
  var assetWriterVideoIn: AVAssetWriterInput?
  var assetWriterInputPixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
  var assetWriterMetadataIn: AVAssetWriterInput?
  var assetWriterMetadataAdaptor: AVAssetWriterInputMetadataAdaptor?
  
  var widthVideo: CGFloat = 0
  var heightVideo: CGFloat = 0 {
    didSet {
      if textOnVideo {
        imageFromText()
      }
    }
  }
  
  var movieWritingQueue: dispatch_queue_t?
  var imageCreateQueue: dispatch_queue_t?
  
  var recording = false
  var readyToRecordAudio = false
  var readyToRecordVideo = false
  var readyToRecordMetadata = false
  var recordingWillBeStarted = false
  var recordingWillBeStopped = false
  
  var inputsReadyToRecord: Bool {
    return readyToRecordAudio && readyToRecordVideo && readyToRecordMetadata
  }
  
  var textOnVideo = false
  
  //MARK: - Init
  
  override init() {
    //print("CaptureManager.init")
    
    super.init()
    
    // Initialize CLLocationManager to receive updates in current location
    locationManager = CLLocationManager()
    locationManager.requestWhenInUseAuthorization()
    locationManager.delegate = self
    
    frc = FrameRateCalculator()
    
    let eaglContext = EAGLContext(API: EAGLRenderingAPI.OpenGLES2)
    ciContext = CIContext(EAGLContext: eaglContext)
    colorSpace = CGColorSpaceCreateDeviceRGB()
    
  }
  
  //MARK: - Asset writing
  
  func writeSampleBuffer(sampleBuffer: CMSampleBufferRef, mediaType: String) {
    //print("CaptureManager.writeSampleBuffer")
    if let assetWriter = self.assetWriter {
      if assetWriter.status == AVAssetWriterStatus.Unknown {
        // If the asset writer status is unknown, implies writing hasn't started yet, hence start writing with start time as the buffer's presentation timestamp
        if assetWriter.startWriting() {
          assetWriter.startSessionAtSourceTime(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
        } else {
          if let error = assetWriter.error {
            //print("ERROR1: CaptureManager.writeSampleBuffer")
            delegate?.showError(error)
          }
        }
      }
      
      if assetWriter.status == AVAssetWriterStatus.Writing {
        // If the asset writer status is writing, append sample buffer to its corresponding asset writer input
        if mediaType == AVMediaTypeVideo {
          if let assetWriterVideoIn = self.assetWriterVideoIn {
            if assetWriterVideoIn.readyForMoreMediaData {
              addingTextToPixelBuffer(sampleBuffer)
            }
          }
        } else if mediaType == AVMediaTypeAudio {
          if let assetWriterAudioIn = self.assetWriterAudioIn {
            if assetWriterAudioIn.readyForMoreMediaData {
              if !assetWriterAudioIn.appendSampleBuffer(sampleBuffer) {
                if let error = assetWriter.error {
                  //print("ERROR3: CaptureManager.writeSampleBuffer")
                  delegate?.showError(error)
                }
              }
            }
          }
        }
      }
    }
  }
  
  func addingTextToPixelBuffer(sampleBuffer: CMSampleBufferRef) {
    
    let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
    
    let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
    
    let options : [String : AnyObject]? = nil // [kCIImageColorSpace : colorSpace!]
    let inputBackImage = CIImage(CVPixelBuffer: pixelBuffer! as CVPixelBuffer, options: options)
    
    var outputImage: CIImage?
    
    if textOnVideo {
      let filter = CIFilter(name: "CISourceOverCompositing")
      filter?.setDefaults()
      filter?.setValue(inputBackImage, forKey: "inputBackgroundImage")
      filter?.setValue(self.ciInputImage, forKey: "inputImage")
      outputImage = filter?.outputImage
    } else {
      outputImage = inputBackImage
    }
    
    var renderedOutputPixelBuffer: CVPixelBuffer? = nil
    
    if let pool = self.assetWriterInputPixelBufferAdaptor?.pixelBufferPool {
      let err = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &renderedOutputPixelBuffer);
      if err == 0 {
        if let buffer = renderedOutputPixelBuffer {
          if let image = outputImage {
            self.ciContext.render(image, toCVPixelBuffer: buffer, bounds: image.extent, colorSpace: self.colorSpace)
            
            //print("IMAGE_SIZE: \(image.extent)")
            
            if let adaptor = self.assetWriterInputPixelBufferAdaptor {
              if !adaptor.appendPixelBuffer(buffer, withPresentationTime: timestamp) {
                print("Timestamp error: \(timestamp) <=======================")
              } else {
                // print("Timestamp: \(timestamp)")
              }
            }
            
            frc.calculateFramerateAtTimestamp(timestamp)
          }
        }
      }
    }
  }
  
  func imageFromText() {
    dispatch_async(imageCreateQueue!, { () -> Void in
      // Setup the font specific variables
      let textColor = UIColor.redColor()
      let backColor = UIColor.clearColor()
      
      var textSize: CGFloat = 10
      
      switch self.scaleText {
      case 0:
        textSize = 12
      case 1:
        textSize = 22
      case 2:
        if self.heightVideo > 640 || self.widthVideo > 640 {
          textSize = 44
        } else {
          textSize = 22
        }
      default:
        break
      }
      
      let textFont: UIFont = UIFont(name: "Helvetica Bold", size: textSize)!
      //Setups up the font attributes that will be later used to dictate how the text should be drawn
      let textFontAttributes = [
        NSFontAttributeName: textFont,
        NSForegroundColorAttributeName: textColor,
        NSBackgroundColorAttributeName: backColor
      ]
      
      let text = "\(self.logotype)\n\(self.time) \(self.speed)\n\(self.coordinate)"
      
      let size = text.sizeWithAttributes(textFontAttributes)
      
      if self.widthVideo != 0 && self.heightVideo != 0 {
        
        UIGraphicsBeginImageContext(CGSize(width: self.widthVideo, height: self.heightVideo))
        
        let context = UIGraphicsGetCurrentContext()
        
        var margin: CGFloat = 20
        
        if self.widthVideo < 320 {
          margin = 10
          switch self.referenceOrientation! {
          case .LandscapeRight, .Portrait:
            CGContextTranslateCTM(context, margin, self.heightVideo-size.height - margin)
            CGContextRotateCTM(context, CGFloat(0))
          case .LandscapeLeft, .PortraitUpsideDown:
            CGContextTranslateCTM(context, self.widthVideo - margin, size.height + margin)
            CGContextRotateCTM(context, CGFloat(M_PI))
          }
          
        } else {
          switch self.referenceOrientation! {
          case .Portrait:
            CGContextTranslateCTM(context, self.widthVideo-size.height - margin, self.heightVideo - margin)
            CGContextRotateCTM(context, CGFloat(-M_PI_2))
          case .PortraitUpsideDown:
            CGContextTranslateCTM(context, size.height + margin, margin)
            CGContextRotateCTM(context, CGFloat(M_PI_2))
          case .LandscapeRight:
            if self.typeCamera == .Front {
              CGContextTranslateCTM(context, self.widthVideo - margin, size.height + margin)
              CGContextRotateCTM(context, CGFloat(M_PI))
            } else {
              CGContextTranslateCTM(context, margin, self.heightVideo-size.height - margin)
              CGContextRotateCTM(context, CGFloat(0))
            }
          case .LandscapeLeft:
            if self.typeCamera == .Front {
              CGContextTranslateCTM(context, margin, self.heightVideo-size.height - margin)
              CGContextRotateCTM(context, CGFloat(0))
            } else {
              CGContextTranslateCTM(context, self.widthVideo - margin, size.height + margin)
              CGContextRotateCTM(context, CGFloat(M_PI))
            }
          }
        }
        // draw in context, you can use also drawInRect:withFont:
        text.drawAtPoint(CGPointMake(0, 0), withAttributes: textFontAttributes)
        // transfer image
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        self.ciInputImage = CIImage(CGImage: image.CGImage!)
        
      }
    })
  }
  
  func setupAssetWriterAudioInput(currentFormatDescription: CMFormatDescriptionRef) -> Bool {
    //print("CaptureManager.setupAssetWriterAudioInput")
    // Create audio output settings dictionary which would be used to configure asset writer input
    let currentASBD = CMAudioFormatDescriptionGetStreamBasicDescription(currentFormatDescription)
    var aclSize: size_t = 0
    let currentChannelLayout = CMAudioFormatDescriptionGetChannelLayout(currentFormatDescription, &aclSize)
    
    // AVChannelLayoutKey must be specified, but if we don't know any better give an empty data and let AVAssetWriter decide.
    var currentChannelLayoutData = NSData()
    if currentChannelLayout != nil && aclSize > 0 {
      currentChannelLayoutData = NSData(bytes: currentChannelLayout, length: aclSize)
    }
    
    let audioCompressionSettings: [String : AnyObject]? = [AVFormatIDKey : NSNumber(unsignedInt: kAudioFormatMPEG4AAC), AVSampleRateKey : NSNumber(double: currentASBD.memory.mSampleRate), AVEncoderBitRatePerChannelKey : NSNumber(integer: 64000), AVNumberOfChannelsKey : NSNumber(unsignedInt: currentASBD.memory.mChannelsPerFrame), AVChannelLayoutKey : currentChannelLayoutData]
    
    if let assetWriter = self.assetWriter {
      if assetWriter.canApplyOutputSettings(audioCompressionSettings, forMediaType: AVMediaTypeAudio) {
        // Intialize asset writer audio input with the above created settings dictionary
        assetWriterAudioIn = AVAssetWriterInput(mediaType: AVMediaTypeAudio, outputSettings: audioCompressionSettings)
        
        if let assetWriterAudioIn = self.assetWriterAudioIn {
          assetWriterAudioIn.expectsMediaDataInRealTime = true
          // Add asset writer input to asset writer
          if assetWriter.canAddInput(assetWriterAudioIn) {
            assetWriter.addInput(assetWriterAudioIn)
          } else {
            print("Couldn't add asset writer audio input.")
            return false
          }
        } else {
          print("Couldn't create asset writer audio input.")
          return false
        }
      } else {
        print("Couldn't apply audio output settings.")
        return false
      }
    } else {
      print("Asset Writer isn't found.")
      return false
    }
    
    return true
  }
  
  func setupAssetWriterVideoInput(currentFormatDescription: CMFormatDescriptionRef) -> Bool {
    //print("CaptureManager.setupAssetWriterVideoInput")
    // Create video output settings dictionary which would be used to configure asset writer input
    var bitsPerPixel: CGFloat = 0
    var bitsPerSecond: UInt = 0
    let dimensions = CMVideoFormatDescriptionGetDimensions(currentFormatDescription)
    
    //print("WIDTH: \(dimensions.width), HEIGHT: \(dimensions.height)")
    widthVideo = CGFloat(dimensions.width)
    heightVideo = CGFloat(dimensions.height)
    
    let numPixels = dimensions.width * dimensions.height
    
    // Assume that lower-than-SD resolutions are intended for streaming, and use a lower bitrate
    if numPixels < 640 * 480 {
      bitsPerPixel = 4.05 // This bitrate matches the quality produced by AVCaptureSessionPresetMedium or Low.
    } else {
      bitsPerPixel =
      10.1 // This bitrate matches the quality produced by AVCaptureSessionPresetHigh.
    }
    bitsPerSecond = UInt(numPixels) * UInt(bitsPerPixel)
    
    let videoCompressionProperties = [AVVideoAverageBitRateKey : NSNumber(unsignedLong: bitsPerSecond), AVVideoMaxKeyFrameIntervalKey : NSNumber(integer: 30)]
    
    let videoCompressionSettings: [String : AnyObject]? = [AVVideoCodecKey : AVVideoCodecH264, AVVideoWidthKey : NSNumber(int: dimensions.width), AVVideoHeightKey : NSNumber(int: dimensions.height), AVVideoCompressionPropertiesKey : videoCompressionProperties]
    
    if let assetWriter = self.assetWriter {
      if assetWriter.canApplyOutputSettings(videoCompressionSettings, forMediaType: AVMediaTypeVideo) {
        // Intialize asset writer video input with the above created settings dictionary
        assetWriterVideoIn = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: videoCompressionSettings)
        if let assetWriterVideoIn = self.assetWriterVideoIn {
          assetWriterVideoIn.expectsMediaDataInRealTime = true
          assetWriterVideoIn.transform = transformFromCurrentVideoOrientationToOrientation(referenceOrientation)
          
          // create a pixel buffer adaptor for the asset writer; we need to obtain pixel buffers for rendering later from its pixel buffer pool
          let sourcePixelBufferAttributes: [String : AnyObject]? =
          [kCVPixelBufferPixelFormatTypeKey as String : NSNumber(unsignedInt: kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey as String : NSNumber(int: dimensions.width),
            kCVPixelBufferHeightKey as String : NSNumber(int: dimensions.height),
            kCVPixelFormatOpenGLESCompatibility as String : kCFBooleanTrue]
          
          assetWriterInputPixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: assetWriterVideoIn, sourcePixelBufferAttributes: sourcePixelBufferAttributes)
          
          // Add asset writer input to asset writer
          if assetWriter.canAddInput(assetWriterVideoIn) {
            assetWriter.addInput(assetWriterVideoIn)
          } else {
            print("Couldn't add asset writer video input.")
            return false
          }
        } else {
          print("Couldn't create asset writer video input.")
          return false
        }
      } else {
        print("Couldn't apply video output settings.")
        return false
      }
    } else {
      print("Asset Writer isn't found.")
      return false
    }
    
    return true
  }
  
  
  func setupAssetWriterMetadataInputAndMetadataAdaptor() -> Bool {
    //print("CaptureManager.setupAssetWriterMetadataInputAndMetadataAdaptor")
    
    // All combinations of identifiers, data types and extended language tags that will be appended to the metadata adaptor must form the specifications dictionary
    var metadataFormatDescription : CMMetadataFormatDescription?
    let specifications = [[kCMMetadataFormatDescriptionMetadataSpecificationKey_Identifier as String: AVMetadataIdentifierQuickTimeMetadataLocationISO6709, kCMMetadataFormatDescriptionMetadataSpecificationKey_DataType as String: kCMMetadataDataType_QuickTimeMetadataLocation_ISO6709 as String], [kCMMetadataFormatDescriptionMetadataSpecificationKey_Identifier as String : FixdriveSpeedIdentifier, kCMMetadataFormatDescriptionMetadataSpecificationKey_DataType as String : kCMMetadataBaseDataType_UTF8 as String], [kCMMetadataFormatDescriptionMetadataSpecificationKey_Identifier as String : FixdriveTimeIdentifier, kCMMetadataFormatDescriptionMetadataSpecificationKey_DataType as String : kCMMetadataBaseDataType_UTF8 as String]]
    
    // Create metadata format description with the above created specifications which will be used to configure asset writer input
    let err = CMMetadataFormatDescriptionCreateWithMetadataSpecifications(kCFAllocatorDefault, kCMMetadataFormatType_Boxed, specifications, &metadataFormatDescription)
    
    if err == 0 {
      // Intialize asset writer video input with the above created specifications
      assetWriterMetadataIn = AVAssetWriterInput(mediaType: AVMediaTypeMetadata, outputSettings: nil, sourceFormatHint: metadataFormatDescription)
      if let assetWriterMetadataIn = self.assetWriterMetadataIn {
        assetWriterMetadataIn.expectsMediaDataInRealTime = true
        // Initialize metadata adaptor with the metadata input with the expected source hint
        assetWriterMetadataAdaptor = AVAssetWriterInputMetadataAdaptor(assetWriterInput: assetWriterMetadataIn)
        
        if let assetWriter = self.assetWriter {
          if assetWriter.canAddInput(assetWriterMetadataIn) {
            assetWriter.addInput(assetWriterMetadataIn)
          } else {
            print("Couldn't add asset writer metadata input.")
            return false
          }
        } else {
          print("Asset Writer isn't found.")
          return false
        }
      } else {
        print("Couldn't create asset writer metadata input.")
        return false
      }
    } else {
      print("Failed to create format description with metadata specification: \(specifications)")
      return false
    }
    
    return true
  }
  
  func startRecording() {
    //print("CaptureManager.startRecording")
    resumeCaptureSession()
    // locationManager.startUpdatingLocation()
    
    dispatch_async(movieWritingQueue!) { () -> Void in
      if self.recordingWillBeStarted || self.recording { return }
      
      self.recordingWillBeStarted = true
      
      // recordingDidStart is called from captureOutput:didOutputSampleBuffer:fromConnection: once the asset writer is setup
      self.delegate?.recordingWillStart()
      
      // Create a new movieURL
      
      self.movieURL = NSURL.fileURLWithPath(NSString(format: "%@%@", NSTemporaryDirectory(), "\(self.createDateString()).mov") as String)
      
      // Create an asset writer
      do {
        try self.assetWriter = AVAssetWriter(URL: self.movieURL, fileType: AVFileTypeQuickTimeMovie)
      } catch {
        //print("ERROR: CaptureManager.startRecording")
        let nserror = error as NSError
        self.delegate?.showError(nserror)
      }
    }
  }
  
  func stopRecording() {
    //print("CaptureManager.stopRecording")
    //pauseCaptureSession()
    //locationManager.stopUpdatingLocation()
    
    if assetWriter == nil {
      return
    }
    
    let writer = assetWriter;
    
    assetWriterAudioIn = nil
    assetWriterVideoIn = nil
    assetWriterInputPixelBufferAdaptor = nil
    assetWriterMetadataIn = nil
    assetWriterMetadataAdaptor = nil
    assetWriter = nil;
    
    
    // recordingDidStop is called from saveMovieToCameraRoll
    self.delegate?.recordingWillStop()
    
    dispatch_async(movieWritingQueue!) { () -> Void in
      if self.recordingWillBeStopped || !self.recording { return }
      self.recordingWillBeStopped = true
      if let writer = writer {
        writer.finishWritingWithCompletionHandler({ () -> Void in
          let completionStatus = writer.status
          switch (completionStatus) {
          case AVAssetWriterStatus.Completed:
            // Save the movie stored in the temp folder into camera roll.
            self.readyToRecordVideo = false
            self.readyToRecordAudio = false
            self.readyToRecordMetadata = false
            //writer = nil
            
            //
            //
            self.recordingWillBeStopped = false
            self.recording = false
            self.delegate?.recordingDidStop()
            self.frc.reset()
            //
            
          case AVAssetWriterStatus.Failed:
            if let error = writer.error {
              //print("ERROR: CaptureManager.stopRecording")
              self.delegate?.showError(error)
            }
          default:
            break
          }
        })
      }
      
      
    }
  }
  
  func startUpdatingLocation() {
    locationManager.startUpdatingLocation()
    //print("LM START")
  }
  
  func stopUpdatingLocation() {
    locationManager.stopUpdatingLocation()
    //print("LM STOP")
  }
  
  //MARK: - Capture
  
  func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
    
    // print("CaptureManager.captureOutput_sampleBuffer")
    dispatch_async(movieWritingQueue!) { () -> Void in
      if self.assetWriter != nil {
        let wasReadyToRecord = self.inputsReadyToRecord
        if (connection == self.videoConnection) {
          // Initialize the video input if this is not done yet
          if (!self.readyToRecordVideo) {
            self.readyToRecordVideo = self.setupAssetWriterVideoInput(CMSampleBufferGetFormatDescription(sampleBuffer)!)
          }
          // Write video data to file only when all the inputs are ready
          if self.inputsReadyToRecord {
            self.writeSampleBuffer(sampleBuffer, mediaType: AVMediaTypeVideo)
          }
        } else if (connection == self.audioConnection) {
          // Initialize the audio input if this is not done yet
          if !self.readyToRecordAudio {
            self.readyToRecordAudio = self.setupAssetWriterAudioInput(CMSampleBufferGetFormatDescription(sampleBuffer)!)
          }
          // Write audio data to file only when all the inputs are ready
          if self.inputsReadyToRecord {
            self.writeSampleBuffer(sampleBuffer, mediaType: AVMediaTypeAudio)
          }
        }
        
        // Initialize the metadata input since capture is about to setup/ already initialized video and audio inputs
        if !self.readyToRecordMetadata {
          self.readyToRecordMetadata = self.setupAssetWriterMetadataInputAndMetadataAdaptor()
        }
        
        
        let isReadyToRecord = self.inputsReadyToRecord
        
        if !wasReadyToRecord && isReadyToRecord {
          self.recordingWillBeStarted = false
          self.recording = true
          self.delegate?.recordingDidStart()
        }
      }
    }
  }
  
  func videoDeviceWithPosition(position: AVCaptureDevicePosition) -> AVCaptureDevice? {
    //print("CaptureManager.videoDeviceWithPosition")
    let devices = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo) as! [AVCaptureDevice]
    for device in devices {
      if device.position == position {
        return device
      }
    }
    return nil
  }
  
  func audioDevice() -> AVCaptureDevice? {
    //print("CaptureManager.audioDevice")
    let devices = AVCaptureDevice.devicesWithMediaType(AVMediaTypeAudio) as! [AVCaptureDevice]
    if devices.count > 0 {
      return devices.first
    }
    return nil
  }
  
  func setupCaptureSession() -> Bool {
    //print("CaptureManager.setupCaptureSession")
    // Create capture session
    captureSession = AVCaptureSession()
    if let session = captureSession {
      // Create audio connection
      do {
        let audioIn = try AVCaptureDeviceInput(device: self.audioDevice())
        if session.canAddInput(audioIn) {
          session.addInput(audioIn)
        }
      } catch {
        print("Could not init audio device")
      }
      
      let audioOut = AVCaptureAudioDataOutput()
      //let audioCaptureQueue = dispatch_queue_create("net.nkpro.fixdrive.audio.queue", DISPATCH_QUEUE_SERIAL)
      audioOut.setSampleBufferDelegate(self, queue: movieWritingQueue!)
      
      if session .canAddOutput(audioOut) {
        session.addOutput(audioOut)
      }
      
      audioConnection = audioOut.connectionWithMediaType(AVMediaTypeAudio)
      
      // Create video connection
      
     setVideoInputOutput(session)
    }
    
    return true
  }
  
  func setupAndStartCaptureSession() {
    //print("CaptureManager.setupAndStartCaptureSession")
    // Create serial queue for movie writing
    movieWritingQueue = dispatch_queue_create("net.nkpro.fixdrive.movie.queue", DISPATCH_QUEUE_SERIAL)
    imageCreateQueue = dispatch_queue_create("net.nkpro.fixdrive.image.queue", DISPATCH_QUEUE_SERIAL)
    
    if let session = captureSession {
      
      NSNotificationCenter.defaultCenter().addObserver(self, selector: "captureSessionStoppedRunningNotification:", name: AVCaptureSessionDidStopRunningNotification, object: session)
      if !session.running {
        session.startRunning()
      }
      
    } else {
      setupCaptureSession()
    }
  }
  
  func pauseCaptureSession() {
    //print("CaptureManager.pauseCaptureSession")
    if let session = captureSession {
      if session.running {
        session.stopRunning()
      }
    }
  }
  
  func resumeCaptureSession() {
    //print("CaptureManager.resumeCaptureSession")
    if let session = captureSession {
      if !session.running {
        session.startRunning()
      }
    }
    
  }
  
  func captureSessionStoppedRunningNotification(notification: NSNotification) {
    //print("CaptureManager.captureSessionStoppedRunningNotification")
    dispatch_async(movieWritingQueue!) { () -> Void in
      if self.recording {
        self.stopRecording()
      }
    }
  }
  
  func stopAndTearDownCaptureSession() {
    //print("CaptureManager.stopAndTearDownCaptureSession")
    if let session = captureSession {
      session.stopRunning()
      NSNotificationCenter.defaultCenter().removeObserver(self, name: AVCaptureSessionDidStopRunningNotification, object: session)
      locationManager.stopUpdatingLocation()
      //print("LM STOP")
    }
    captureSession = nil
  }
  
  func changeTypeCamera() {
    //if typeCamera == .Front {
      delegate?.setupPreviewLayer()
    //}
    if let session = captureSession {
      session.stopRunning()
      session.beginConfiguration()
      
      session.removeInput(videoIn)
      session.removeOutput(videoOut)
      session.removeOutput(photoOut)
      videoIn = nil
      videoDevice = nil
      
      setVideoInputOutput(session)
      
      session.commitConfiguration()
      session.startRunning()
    }
  }
  
  func setVideoInputOutput(session: AVCaptureSession) {
    var position: AVCaptureDevicePosition!
    if typeCamera == .Front {
      position = .Front
    } else {
      position = .Back
    }
    
    videoDevice = videoDeviceWithPosition(position)
    
    setAutofocusing()
    
    do {
      videoIn = try AVCaptureDeviceInput(device: videoDevice)
      if session.canAddInput(videoIn) {
        session.addInput(videoIn)
      }
    } catch {
      print("Could not init input video device")
    }
    
    videoOut = AVCaptureVideoDataOutput()
    videoOut.alwaysDiscardsLateVideoFrames = true
    let videoSettings: [NSObject : AnyObject]! = [kCVPixelBufferPixelFormatTypeKey : NSNumber(unsignedInt: kCVPixelFormatType_32BGRA)]
    videoOut.videoSettings = videoSettings
    //let videoCaptureQueue = dispatch_queue_create("net.nkpro.fixdrive.video.queue", DISPATCH_QUEUE_SERIAL)
    videoOut.setSampleBufferDelegate(self, queue: movieWritingQueue)
    
    if session .canAddOutput(videoOut) {
      session.addOutput(videoOut)
    }
    
    videoConnection = videoOut.connectionWithMediaType(AVMediaTypeVideo)
    videoOrientation = videoConnection?.videoOrientation
    
    photoOut = AVCaptureStillImageOutput()
    if session.canAddOutput(photoOut) {
      photoOut.outputSettings = [AVVideoCodecKey : AVVideoCodecJPEG]
      session.addOutput(photoOut)
    }
    
    photoConnection = photoOut.connectionWithMediaType(AVMediaTypeVideo)
    //photoConnection?.videoOrientation = referenceOrientation
    
 
  }
  
  func snapImage() {
    
    photoConnection?.videoOrientation = referenceOrientation
    print("ReferenceOrientation: \(referenceOrientation.rawValue)")
    
    guard let photoConnection = self.photoConnection else { return }
    
    dispatch_async(movieWritingQueue!) {
      self.photoOut.captureStillImageAsynchronouslyFromConnection(photoConnection) {
        imageDataSampleBuffer, error in
        if let error = error {
          print(error.localizedDescription)
        } else {
          let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(imageDataSampleBuffer)
          if let image = UIImage(data: imageData) {
            PHPhotoLibrary.sharedPhotoLibrary().performChanges({ () -> Void in
              PHAssetCreationRequest.creationRequestForAssetFromImage(image)
              }) { (success, error) -> Void in
                if let nserror = error {
                  print("ERROR: CM.snapImage - \(nserror.localizedDescription)")
                }
                if success {
                  // print("Image saved")
                } else {
                  // print("Image didn't save")
                }
            }
          }
        }
      }
    }
    
  }
  
  func setAutofocusing() {
    if let device = videoDevice {
      var mode: AVCaptureFocusMode = .AutoFocus
      if autofocusing! {
        mode = .ContinuousAutoFocus
      }
      if device.isFocusModeSupported(mode) {
        do {
          try device.lockForConfiguration()
          device.focusMode = mode
          device.unlockForConfiguration()
        } catch {
          print("Could not lock video device")
        }
      }
    }
  }
  
  //MARK: - Utilities
    
  func cmTimeForNSDate(date: NSDate) -> CMTime {
    //print("CaptureManager.cmTimeForNSDate")
    let now = CMClockGetTime(CMClockGetHostTimeClock())
    let elapsed = -(date.timeIntervalSinceNow) // this will be a negative number if date was in the past (it should be).
    let subtact = CMTimeMake(Int64(elapsed) * Int64(now.timescale), Int32(now.timescale))
    let eventTime = CMTimeSubtract(now, subtact)
    
    return eventTime
  }
  
  func movieTimeForLocationTime(date: NSDate) -> CMTime {
    //print("CaptureManager.movieTimeForLocationTime")
    let locationTime = cmTimeForNSDate(date)
    let locationMovieTime = CMSyncConvertTime(locationTime, CMClockGetHostTimeClock(), captureSession!.masterClock)
    
    return locationMovieTime;
  }
  
  func angleOffsetFromPortraitOrientationToOrientation(orientation: AVCaptureVideoOrientation, video: Bool) -> CGFloat {
    //print("CaptureManager.angleOffsetFromPortraitOrientationToOrientation")
    var angle: CGFloat = 0.0
    
    if typeCamera == .Back || video {
    
      switch (orientation)
      {
      case AVCaptureVideoOrientation.Portrait:
        angle = 0.0
        break
      case AVCaptureVideoOrientation.PortraitUpsideDown:
        angle = CGFloat(M_PI)
        break
      case AVCaptureVideoOrientation.LandscapeRight:
        angle = -CGFloat(M_PI_2)
        break
      case AVCaptureVideoOrientation.LandscapeLeft:
        angle = CGFloat(M_PI_2)
        break
      }
      
    } else {
      
      switch (orientation)
      {
      case AVCaptureVideoOrientation.Portrait:
        angle = CGFloat(M_PI)
        break
      case AVCaptureVideoOrientation.PortraitUpsideDown:
        angle = 0.0
        break
      case AVCaptureVideoOrientation.LandscapeRight:
        angle = -CGFloat(M_PI_2)
        break
      case AVCaptureVideoOrientation.LandscapeLeft:
        angle = CGFloat(M_PI_2)
        break
      }

      
    }
    
    return angle;
    
  }
  
  func transformFromCurrentVideoOrientationToOrientation(orientation: AVCaptureVideoOrientation) -> CGAffineTransform {
    //print("CaptureManager.transformFromCurrentVideoOrientationToOrientation")
    var transform = CGAffineTransformIdentity
    
    // Calculate offsets from an arbitrary reference orientation (portrait)
    let orientationAngleOffset = angleOffsetFromPortraitOrientationToOrientation(orientation, video: false)
    let videoOrientationAngleOffset = angleOffsetFromPortraitOrientationToOrientation(videoOrientation, video: true)
    
    // Find the difference in angle between the passed in orientation and the current video orientation
    let angleOffset = orientationAngleOffset - videoOrientationAngleOffset
    transform = CGAffineTransformMakeRotation(angleOffset);
    
    return transform
    
  }
  
  func createDateString() -> String {
    //print("CaptureManager.createDateString")
    let dateFormater = NSDateFormatter()
    //dateFormater.dateFormat = "yy/MM/dd HH:mm:ss"
    dateFormater.dateFormat = "yyMMdd_HHmmss"
    
    return dateFormater.stringFromDate(NSDate())
  }
  
  func distanceFromInterva(interval: Int) -> CLLocationDistance {
    if interval == 0 {
      return kCLDistanceFilterNone
    } else {
      return Double(interval)
    }
  }

}

//MARK: - CLLocationManagerDelegate

extension CaptureManager : CLLocationManagerDelegate {
  
  func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    //print("CaptureManager.locationManager_didUpdateLocations")
    
    for newLocation in locations {
      
      //print("Distance: \(locationManager.distanceFilter)")
      
      // Disregard location updates that aren't accurate to within 50 meters.
      
      if newLocation.horizontalAccuracy > 50.0 { continue } // set 50
      
      // Test the age of the location measurement to determine if the measurement is cached
      if -(newLocation.timestamp.timeIntervalSinceNow) > 5.0 { continue }
      
      self.delegate?.distanceUpdate(newLocation)
      
      var kSpeed: Float = 3.6
      var strSpeed = NSLocalizedString("km/h", comment: "CaptureManager: km/h")
      if self.typeSpeed == .Mi {
        kSpeed = 2.236936
        strSpeed = NSLocalizedString("mph", comment: "CaptureManager: mph")
      }
      
      var locationSpeed = Float(newLocation.speed)
      
      if locationSpeed < 0 || locationSpeed > 1000 {
        locationSpeed = 0
      }
      
      let speed = Int(locationSpeed*kSpeed)
      let speedStr = NSString(format: "%d %@", speed, strSpeed) as String
      
      self.speed = speedStr
      
        self.delegate?.newLocationUpdate(speedStr)
        //print("SPEED: \(speedStr)")

      
      dispatch_async(movieWritingQueue!, { () -> Void in
        if let assetWriter = self.assetWriter {
          if assetWriter.status == AVAssetWriterStatus.Writing {
            
            let metadataItem = AVMutableMetadataItem()
            metadataItem.identifier = AVMetadataIdentifierQuickTimeMetadataLocationISO6709
            metadataItem.dataType = kCMMetadataDataType_QuickTimeMetadataLocation_ISO6709 as String
            // CoreLocation objects contain altitude information as well
            // If you need to store an ISO 6709 notation which includes altitude too, append it at the end of the string below
            let iso6709Notation = NSString(format: "%+08.4lf%+09.4lf/", newLocation.coordinate.latitude, newLocation.coordinate.longitude)
            
            var latitudeStr = ""
            var longitudeStr = ""
            
            if newLocation.coordinate.latitude >= 0 {
              latitudeStr = NSString(format: "N:%9.5lf", newLocation.coordinate.latitude) as String
            } else {
              latitudeStr = NSString(format: "S:%9.5lf", -newLocation.coordinate.latitude)  as String
            }
            
            if newLocation.coordinate.longitude >= 0 {
              longitudeStr = NSString(format: "E:%9.5lf", newLocation.coordinate.longitude) as String
            } else {
              longitudeStr = NSString(format: "W:%9.5lf", -newLocation.coordinate.longitude)  as String
            }
            
            self.coordinate = "\(latitudeStr), \(longitudeStr)"
            
            metadataItem.value = iso6709Notation
            
            // Annotation speed item
            let speedItem = AVMutableMetadataItem()
            speedItem.identifier = FixdriveSpeedIdentifier
            speedItem.dataType = kCMMetadataBaseDataType_UTF8 as String
            speedItem.value = String(format: "%07.2f", locationSpeed)
            
            // Annotation time item
            let timeItem = AVMutableMetadataItem()
            timeItem.identifier = FixdriveTimeIdentifier
            timeItem.dataType = kCMMetadataBaseDataType_UTF8 as String
            timeItem.value = self.time
            
            
            // Convert location time to movie time
            let locationMovieTime = CMTimeConvertScale(self.movieTimeForLocationTime(newLocation.timestamp), 1000, CMTimeRoundingMethod.Default)
            let newGroup = AVTimedMetadataGroup(items: [metadataItem, speedItem, timeItem], timeRange: CMTimeRangeMake(locationMovieTime, kCMTimeInvalid))
            
            if let assetWriterMetadataIn = self.assetWriterMetadataIn, let assetWriterMetadataAdaptor = self.assetWriterMetadataAdaptor {
              if assetWriterMetadataIn.readyForMoreMediaData {
                if assetWriterMetadataAdaptor.appendTimedMetadataGroup(newGroup) {
                  // print("LOC_UPDATE")
                } else {
                  if let error = assetWriter.error {
                    print("ERROR: CaptureManager.locationManager_didUpdateLocations")
                    self.delegate?.showError(error)
                  }
                }
              }
            }
          }
        }
      })
    }
  }
}


