//
//  PlayerViewController.swift
//  FixDrive
//
//  Created by NK on 06.10.15.
//  Copyright © 2015 Nikolay Kolesnikov. All rights reserved.
//

// http://stackoverflow.com/questions/32639728/mpmovieplayer-in-ios-9

import UIKit
import AVKit
import MapKit
import AVFoundation
import CoreMedia
import iAd
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}


class PlayerViewController : UIViewController {
  
  enum MapMode : Int {
    case none = 0
    case centered = 1
    case distance = 2
  }
  
  var url: URL!
  var player: AVPlayer!
  var typeSpeed: TypeSpeed!
  var asset: AVAsset!
  var uiImage: UIImage!
  var location: CLLocation?
  
  // Reader variables
  fileprivate var reader: AVAssetReader!
  fileprivate var readerMetadataOutput: AVAssetReaderTrackOutput!
  fileprivate var metadataAdaptor: AVAssetReaderOutputMetadataAdaptor!
  fileprivate var readerQueue: DispatchQueue!
  
  // Output variable
  fileprivate var metadataOutput: AVPlayerItemMetadataOutput!
  
  // Location variables
  fileprivate var metadatas = [Metadata]()
  fileprivate var currentPin: MKPointAnnotation!
  fileprivate var playerMapMode: MapMode = .centered
  fileprivate var startPoint: Metadata!
  fileprivate var endPoint: Metadata!
  fileprivate var distancePolyline: MKPolyline?
  
  @IBOutlet weak var mapView: MKMapView!
  @IBOutlet weak var playerStack: UIStackView!
  @IBOutlet weak var trackStatusLabel: UILabel!
  @IBOutlet weak var mapTypeButton: UIButton!
  @IBOutlet weak var centeredButton: UIButton!
  @IBOutlet weak var distanceButton: UIButton!
  @IBOutlet weak var photoImage: UIImageView!

  
  override func viewDidLoad() {
    super.viewDidLoad()
    mapTypeButton.layer.cornerRadius = 10
    mapTypeButton.layer.backgroundColor = UIColor(red: 176.0/255.0, green: 176.0/255.0, blue: 176.0/255.0, alpha: 0.5).cgColor
    
    //trackStatusLabel.layer.backgroundColor = UIColor(red: 176.0/255.0, green: 176.0/255.0, blue: 176.0/255.0, alpha: 0.5).CGColor
    //trackStatusLabel.layer.cornerRadius = 10.0
    
    self.centeredButton.isEnabled = false
    self.distanceButton.isEnabled = false
    
    defineStackAxis()
    let notificationCenter = NotificationCenter.default
    notificationCenter.addObserver(self, selector: #selector(PlayerViewController.defineStackAxis), name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
    //notificationCenter.addObserver(self, selector: "didPlayToEndTime", name: AVPlayerItemDidPlayToEndTimeNotification, object: nil)

  }
  
  override func viewWillDisappear(_ animated: Bool) {
    //print("CameraVC.viewWillDisappear")
    super.viewWillDisappear(animated)
    
    PicturesList.pList.pictures.sort(by: { $0.date.compare($1.date as Date) == ComparisonResult.orderedDescending })
    PicturesList.pList.savePictures()
  }
  
  func didPlayToEndTime(){
    // print("didPlayToEndTime")
  }
  
  func defineStackAxis() {
    let orientation = UIDevice.current.orientation
    if orientation.isPortrait {
      playerStack.axis = .vertical
    }
    if orientation.isLandscape {
      playerStack.axis = .horizontal
    }
  }
  
  deinit {
    let notificationCenter = NotificationCenter.default
    notificationCenter.removeObserver(self, name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
    player = nil
    url = nil
  }
  
  override var prefersStatusBarHidden : Bool {
    return true
  }
  
  func setupVariables() {
    // print("setupVariables")
    
    // Initialize reader queue to perform all reading related operations on a background queue
    readerQueue = DispatchQueue(label: "net.nkpro.fixdrive.reader.queue", attributes: [])
    
    // Initialize metadata output with location identifier to get delegate callbacks with location metadata groups
    let metadataQueue = DispatchQueue(label: "net.nkpro.fixdrive.metadata.queue", attributes: [])
    
    metadataOutput = AVPlayerItemMetadataOutput(identifiers: [AVMetadataIdentifierQuickTimeMetadataLocationISO6709, FixdriveSpeedIdentifier, FixdriveTimeIdentifier])
    metadataOutput.setDelegate(self, queue: metadataQueue)
    
    setCentered()
    
    asset = AVURLAsset(url: url)
    let playerItem = AVPlayerItem(asset: asset)
    
    // Add metadata output to player item to get delegate callbacks during playback
    playerItem.add(metadataOutput)
    
    player = AVPlayer(playerItem: playerItem)
    
    //player.videoGravity = AVLayerVideoGravityResizeAspect
    mapView.delegate = self
    mapView.mapType = .standard
    
    readMetadataFromAsset(asset) { (metadataAvailable) -> Void in
      // Draw path on map only if we have location metadata
      if metadataAvailable {
        self.drawPathOnMap()
        self.trackStatusLabel.text = ""
        self.centeredButton.isEnabled = true
        self.distanceButton.isEnabled = true
      } else {
        //print("The input movie \(asset.URL) does not contain location metadata")
        self.trackStatusLabel.text = NSLocalizedString("No Data", comment: "PlayerVC: No Data")
      }
      self.player.play()
    }
  }
  
  // MARK: - Actions
    
  @IBAction func setPointOnMap(_ sender: UITapGestureRecognizer) {
    // print("TAP: setPointOnMap")
    if sender.state == .ended {
      let point = sender.location(in: mapView)
      let locCoord = mapView.convert(point, toCoordinateFrom: mapView)
      let newLocation = CLLocation(latitude: locCoord.latitude, longitude: locCoord.longitude)
      if playerMapMode == .distance {
        setDistancePoint(newLocation)
      } else {
        userDidSeekToNewPosition(newLocation)
      }
    }
  }
  
  @IBAction func exit(_ sender: UIButton!) {
    player.pause()
    dismiss(animated: false, completion: nil)
  }
  
  
  @IBAction func setMapType(_ sender: UIButton) {
    if mapView.mapType == .standard {
      mapView.mapType = .satellite
      mapTypeButton.setTitle(NSLocalizedString("Standard", comment: "PlayerVC: Standard"),
        for: UIControlState())
    } else {
      mapView.mapType = .standard
      mapTypeButton.setTitle(NSLocalizedString("Satellite", comment: "PlayerVC: Satellite"),
        for: UIControlState())
    }
  }
  
  @IBAction func tapCenteredButton(_ sender: UIButton) {

    switch playerMapMode {
    case .none:
      playerMapMode = .centered
      setCentered()
    case .distance:
      playerMapMode = .centered
      resetDistanceMode()
      setCentered()
    case .centered:
      playerMapMode = .none
      setUncentered()
    }
    
  }
  
  @IBAction func tapDistanceButton(_ sender: UIButton) {
    switch playerMapMode {
    case .none:
      playerMapMode = .distance
      setDistanceMode()
    case .centered:
      playerMapMode = .distance
      setUncentered()
      setDistanceMode()
    case .distance:
      playerMapMode = .none
      resetDistanceMode()
    }
  }
  
  @IBAction func takePhoto(_ sender: UIButton) {
    
    if PicturesList.pList.pictures.count >= maxNumberPictures && !IAPHelper.iapHelper.setFullVersion {
      // show alert
      // print("ALERT")
      showAlert()
    } else {
      
      let time = player.currentTime()
      let date = photoDate(time)
      // print("Date: \(date)")
      let imageGenerator = AVAssetImageGenerator(asset: asset)
      let imageTimeValue = NSValue(time: time)
      
      imageGenerator.appliesPreferredTrackTransform = true
      imageGenerator.generateCGImagesAsynchronously(forTimes: [imageTimeValue], completionHandler: { (requestedTime, image, actualTime, result, error) -> Void in
        if let cgImage = image {
          self.uiImage = UIImage(cgImage: cgImage)
          DispatchQueue.main.async{
            self.photoImage.image = self.uiImage.thumbnailOfSize(CGSize(width: 60, height: 60))
          }
          if let picture = Picture(image: self.uiImage, date: date, location: self.location) {
            PicturesList.pList.pictures.append(picture)
            //PicturesList.pList.pictures.sortInPlace({ $0.date.compare($1.date) == NSComparisonResult.OrderedDescending })
            //PicturesList.pList.savePictures()
          }
        }
      })
    }
  }
  
  @IBAction func openZoomingController(_ sender: AnyObject) {
    if uiImage != nil {
      player.pause()
      self.performSegue(withIdentifier: "zoomSegue", sender: nil)
    }
  }
  
  func photoDate(_ timestamp: CMTime) -> Date {
    
    if let timeFirst = metadatas.first?.time {
      let dateFormater = DateFormatter()
      dateFormater.dateFormat = "yyyy/MM/dd HH:mm:ss"
      if let date = dateFormater.date(from: timeFirst) {
        let delta = CMTimeGetSeconds(timestamp)

        return date.addingTimeInterval(delta)
      }
    }
    return Date()
  }
  
  func setDistancePoint(_ newLocation: CLLocation) {
    var updatedMetadata: Metadata? = nil
    var closestDistance: CLLocationDistance = DBL_MAX
    
    // Find the closest location on the path to which we can seek
    for metadata in metadatas {
      let distance = newLocation.distance(from: metadata.location!)
      if distance < closestDistance {
        updatedMetadata = metadata
        closestDistance = distance
      }
    }
    
    let distanceToStart = updatedMetadata?.location?.distance(from: startPoint.location!)
    let distanceToEnd = updatedMetadata?.location?.distance(from: endPoint.location!)
    
    if distanceToStart < distanceToEnd {
      mapView.removeAnnotation(startPoint)
      startPoint = updatedMetadata
      mapView.addAnnotation(startPoint)
    } else {
      mapView.removeAnnotation(endPoint)
      endPoint = updatedMetadata
      mapView.addAnnotation(endPoint)
    }
    
    if let distancePolyline = distancePolyline {
      mapView.remove(distancePolyline)
    }
    
    if let startIndex = metadatas.index(of: startPoint) {
      if let endIndex = metadatas.index(of: endPoint) {
        dataFromPointsWithIndexes(startIndex: startIndex, endIndex: endIndex)
        
        var pointsToUse = [CLLocationCoordinate2D]()
        
        // Extract all the coordinates to draw from the locationPoints array
        guard startIndex <= endIndex else { return }
        for i in startIndex ... endIndex {
          let metadata = metadatas[i]
          pointsToUse.append(metadata.coordinate)
        }
        
        // Draw the extracted path as an overlay on the map view
        distancePolyline = MKPolyline(coordinates: &pointsToUse, count: pointsToUse.count)
        if let distancePolyline = distancePolyline {
          mapView.add(distancePolyline, level: .aboveRoads)
        }
      }
    }
    
  }
  
  func userDidSeekToNewPosition(_ newLocation: CLLocation) {
    // print("userDidSeekToNewPosition")
    
    var updatedMetadata: Metadata? = nil
    var closestDistance: CLLocationDistance = DBL_MAX
    
    // Find the closest location on the path to which we can seek
    for metadata in metadatas {
      let distance = newLocation.distance(from: metadata.location!)
      if distance < closestDistance {
        updatedMetadata = metadata
        closestDistance = distance
      }
    }
    
    if let updatedMetadata = updatedMetadata {
      DispatchQueue.main.async(execute: { () -> Void in
        // Seek to timestamp of the updated location.
        let updatedTimeRange = updatedMetadata.timestamp!
        
        self.player.seek(to: updatedTimeRange.start, completionHandler: { (finished) -> Void in
          // Start centering the map at the current location
          // self.setCentered()
          // Move the pin to updated location.
          if finished {
            self.updateCurrentLocation(updatedMetadata.location!)
          }
        })
      })
    }
  }
  
  // MARK: - Asset reading
  
  func readMetadataFromAsset(_ asset: AVAsset, completionHandler: @escaping ((Bool) -> Void)) {
    // print("readMetadataFromAsset")
    
    asset.loadValuesAsynchronously(forKeys: ["tracks"]) { () -> Void in
      // Dispatch all the reading work to a background queue, so we do not block the main thread
      self.readerQueue.async(execute: { () -> Void in
        var error: NSError?
        var success = (asset.statusOfValue(forKey: "tracks", error: &error) == .loaded)
        
        // Set up the AVAssetReader reading samples or flag an error
        if success {
          success = self.setUpReaderForAsset(asset)
        } else {
          
            return
          
        }
        // Start reading in the location metadata from asset reader output, which we can later draw on a map
        if success {
          success = self.startReadingLocationMetadata()
        }
        
        // Call completion handler with the appropriate BOOL indicating presence or absence of metadata
        var metadataAvailable = false
        if success {
          metadataAvailable = self.metadatas.count > 0
        } else {
          self.reader.cancelReading()
        }
        
        // The completion handler involves changes to the map view, which should be performed on the main thread
        DispatchQueue.main.async { () -> Void in
          completionHandler(metadataAvailable)
        }
      })
    }
  }
  
  func setUpReaderForAsset(_ asset: AVAsset) -> Bool {
    // print("setUpReaderForAsset")
    
    var success = true
    
    // Create asset reader
    do {
      reader = try AVAssetReader(asset: asset)
    } catch {
      let nserror = error as NSError
      print("ERROR: PlayerVC.setUpReaderForAsset - \(nserror.userInfo)")
      success = false
    }
    
    // Check to see if a metadata track which contains location information is present
    var locationTrack: AVAssetTrack? = nil
    if success {
      // Go through the metadata tracks in the asset to find the track with location metadata
      let metadataTracks = asset.tracks(withMediaType: AVMediaTypeMetadata)
      for track in metadataTracks {
        
        for formatDescription in track.formatDescriptions {
          // Check if the format description for the track contains location identifier
          
          var identifiers: NSArray? = nil
          
          identifiers = CMMetadataFormatDescriptionGetIdentifiers(formatDescription as! CMMetadataFormatDescription)
          
          if let identifiers = identifiers {
            if identifiers.contains(AVMetadataIdentifierQuickTimeMetadataLocationISO6709) {
              locationTrack = track
              break
            }
          }
        }
      }
    }
    
    success = (locationTrack != nil)
    
    // Create an asset reader output and metadata adaptor only if we have a track containing location metadata
    if success {
      readerMetadataOutput = AVAssetReaderTrackOutput(track: locationTrack!, outputSettings: nil)
      metadataAdaptor = AVAssetReaderOutputMetadataAdaptor(assetReaderTrackOutput: readerMetadataOutput)
      reader.add(readerMetadataOutput)
    }
    
    return success
  }
  
  func startReadingLocationMetadata() -> Bool {
    // print("startReadingLocationMetadata")
    
    // Instruct the asset reader to get ready to do work
    let success = reader.startReading()
    
    if success {
      // Read in all the timed metadata groups from the track and save it in an array to use for drawing on the map later
      // The corresponding time stamps for the location data are stored in another array
      var group = metadataAdaptor.nextTimedMetadataGroup()
      
      while group != nil {
        let location = locationFromMetadataGroup(group!)
        if let location = location {
          let metadata = Metadata()
          metadata.location = location
          metadata.timestamp = group!.timeRange
          if let speed = speedFromMetadataGroup(group!) {
            metadata.speed = speed
          }
          if let time = timeFromMetadataGroup(group!) {
            metadata.time = time
          }
          metadatas.append(metadata)
        }
        group = metadataAdaptor.nextTimedMetadataGroup()
      }
      startPoint = metadatas.first
      endPoint = metadatas.last
    } else {
      if let error = player.error as? NSError {
        print("ERROR: startReadingLocationMetadata - \(error.userInfo)")
      }
    }
    
    return success
  }
  
  // MARK: - Utilites
  
  func drawPathOnMap() {
    // print("drawPathOnMap")
    
    let numberOfPoints = metadatas.count
    var pointsToUse = [CLLocationCoordinate2D](repeating: CLLocationCoordinate2D(), count: numberOfPoints)
    
    // Extract all the coordinates to draw from the locationPoints array
    for i in 0 ..< numberOfPoints {
      let metadata = metadatas[i]
      pointsToUse[i] = metadata.location!.coordinate
    }
    
    // Draw the extracted path as an overlay on the map view
    let polyline = MKPolyline(coordinates: &pointsToUse, count: numberOfPoints)
    mapView.add(polyline, level: .aboveRoads)
    
    // Set initial coordinate to the starting coordinate of the path
    mapView.centerCoordinate = metadatas.first!.location!.coordinate
    
    var distance: Double = 0.0
    
    if numberOfPoints > 0 {
      distance = max(metadatas.first!.location!.distance(from: metadatas.last!.location!) * 1.5, 800.0)
    }
    
    // Set initial region to some region around the starting coordinate
    mapView.region = MKCoordinateRegionMakeWithDistance(mapView.centerCoordinate, distance, distance)
    
    currentPin = MKPointAnnotation()
    currentPin.coordinate = mapView.centerCoordinate
    mapView.addAnnotation(currentPin)
    
  }
  
  func drawDistancePath() {
    mapView.removeAnnotation(currentPin)
    mapView.addAnnotations([startPoint, endPoint])
    
    if let startIndex = metadatas.index(of: startPoint) {
      if let endIndex = metadatas.index(of: endPoint) {
        dataFromPointsWithIndexes(startIndex: startIndex, endIndex: endIndex)
        
        var pointsToUse = [CLLocationCoordinate2D]()
        
        // Extract all the coordinates to draw from the locationPoints array
        guard startIndex <= endIndex else { return }
        for i in startIndex ... endIndex {
          let metadata = metadatas[i]
          pointsToUse.append(metadata.coordinate)
        }
        
        // Draw the extracted path as an overlay on the map view
        distancePolyline = MKPolyline(coordinates: &pointsToUse, count: pointsToUse.count)
        if let distancePolyline = distancePolyline {
          mapView.add(distancePolyline, level: .aboveRoads)
        }
      }
    }
    
  }
  
  
  func removeDistancePath() {
    if let distancePolyline = distancePolyline {
      mapView.remove(distancePolyline)
    }
    mapView.removeAnnotations([startPoint, endPoint])
    mapView.addAnnotation(currentPin)
  }
  
  func locationFromMetadataGroup(_ group: AVTimedMetadataGroup) -> CLLocation? {
    // print("locationFromMetadataGroup")
    
    var location: CLLocation? = nil
    
    // Go through the timed metadata group to extract location value
    for item in group.items {
      // Check to see if the item's data type matches quick time metadata location data type
      
      if let itemString = item.identifier {
        if itemString == AVMetadataIdentifierQuickTimeMetadataLocationISO6709 {
          if let locationDescription = item.stringValue {
            // Extract from a string in iso6709 notation
            let latitude = (locationDescription as NSString).substring(to: 8)
            let longitude = (locationDescription as NSString).substring(with: NSMakeRange(8, 9))
            location = CLLocation(latitude: (latitude as NSString).doubleValue, longitude: (longitude as NSString).doubleValue)
          }
         break
        }
      }
    }
    
    return location
  }
  
  func speedFromMetadataGroup(_ group: AVTimedMetadataGroup) -> String? {
    // print("speedFromMetadataGroup")
    
    var speed: String? = nil
    
    // Go through the timed metadata group to extract location value
    for item in group.items {
      // Check to see if the item's data type matches quick time metadata location data type
      
      if let itemString = item.identifier {
        if itemString == FixdriveSpeedIdentifier {
          if let speedDescription = item.stringValue {
            speed = speedDescription
            //print("Speed: \(speedDescription)")
          }
          break
        }
      }
    }
    return speed
  }
  
  func timeFromMetadataGroup(_ group: AVTimedMetadataGroup) -> String? {
    // print("timeFromMetadataGroup")
    
    var time: String? = nil
    
    // Go through the timed metadata group to extract location value
    for item in group.items {
      // Check to see if the item's data type matches quick time metadata location data type
      
      if let itemString = item.identifier {
        if itemString == FixdriveTimeIdentifier {
          if let timeDescription = item.stringValue {
            time = timeDescription
            // print("Time: \(timeDescription)")
          }
          break
        }
      }
    }
    return time
  }
  
  
  
  func updateCurrentLocation(_ location: CLLocation) {
    // print("updateCurrentLocation")
    // Update current pin to the new location
    DispatchQueue.main.async { () -> Void in
      if let currentPin = self.currentPin {
        currentPin.coordinate = location.coordinate
        if self.playerMapMode == .centered {
          self.mapView.setCenter(currentPin.coordinate, animated: true)
          self.mapView.addAnnotation(currentPin)
        }
      }
    }
  }
  
  func setCentered() {
    // print("setCentered")
    centeredButton.setImage(UIImage(named: "CenteredHi"), for: UIControlState())
    DispatchQueue.main.async { () -> Void in
      if let currentPin = self.currentPin {
        self.mapView.setCenter(currentPin.coordinate, animated: true)
      }
    }
  }
  
  func setUncentered() {
    // print("setUncentered")

    centeredButton.setImage(UIImage(named: "Centered"), for: UIControlState())
  }
  
  func setDistanceMode() {
    distanceButton.setImage(UIImage(named: "DistanceHi"), for: UIControlState())
    
    drawDistancePath()
  }
  
  func resetDistanceMode() {
    distanceButton.setImage(UIImage(named: "Distance"), for: UIControlState())
    trackStatusLabel.text = ""
    removeDistancePath()
  }
  
  func distanceString(_ distance: String) -> String {
    var unitSpeedStr = ""
    var kSpeed: Float = 0
    
    let mphStr = NSLocalizedString("mph", comment: "PlayerVC: mph")
    let kmhStr = NSLocalizedString("km/h", comment: "PlayerVC: km/h")
    
    if typeSpeed == .mi {
      //print("mph")
      kSpeed = 2.236936
      unitSpeedStr = mphStr
    } else {
      //print("km/h")
      kSpeed = 3.6
      unitSpeedStr = kmhStr
    }
    
    let floatSpeed = (distance as NSString).floatValue * kSpeed
    return "\(Int(floatSpeed)) \(unitSpeedStr)"
  }
  
  func dataFromPointsWithIndexes(startIndex: Int, endIndex: Int) {
    var distance: Double = 0
    var index = startIndex
    var metadata = metadatas[index]
    
    var time: Int64 = 0
    
    if let startTime = metadatas[startIndex].timestamp?.start {
      if let endTime = metadatas[endIndex].timestamp?.start {
        time = endTime.value / Int64(endTime.timescale) - startTime.value / Int64(startTime.timescale)
      }
    }
    
    let seconds = Int(time % 60)
    let minutes = Int(((time - seconds) / 60) % 60)
    let hours = Int(((time - seconds) / 60 - minutes) / 60)
    
    let timeString = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    
    //print("TIME: \(timeString), time: \(time), seconds: \(seconds), minutes: \(minutes), hours: \(hours)")
    
    var minSpeed: Float = 10000
    var maxSpeed: Float = 0
    
    var unitSpeedStr = ""
    var kSpeed: Float = 0
    
    let mphStr = NSLocalizedString("mph", comment: "PlayerVC: mph")
    let kmhStr = NSLocalizedString("km/h", comment: "PlayerVC: km/h")
    
    if typeSpeed == .mi {
      //print("mph")
      kSpeed = 2.236936
      unitSpeedStr = mphStr
    } else {
      //print("km/h")
      kSpeed = 3.6
      unitSpeedStr = kmhStr
    }
    
    while index < endIndex {
      
      if metadata.speed.hasSuffix("mph") || metadata.speed.hasSuffix("km/h") || metadata.speed.hasSuffix("км/ч") {
        print("OLD DATA")
      } else {
        let speedFull = metadata.speed as NSString
        let speed = speedFull.floatValue * kSpeed
        
        minSpeed = min(minSpeed, speed)
        maxSpeed = max(maxSpeed, speed)
      }
    
      //print("+++\(speed)+++")
      index += 1
      let delta = metadata.location!.distance(from: metadatas[index].location!)
      if delta > Double(Odometer.accuracity) {
        distance += delta
        metadata = metadatas[index]
      }
    }
    
    var avgSpeed: Int = 0
    if time != 0 {
      avgSpeed = Int(Float(distance) / Float(time) * kSpeed)
    }
    
    if minSpeed == 10000 {
      minSpeed = 0
    }
    
    let mStr = NSLocalizedString("m", comment: "PlayerVC: m")
    let minStr = NSLocalizedString("min:", comment: "PlayerVC: min:")
    let maxStr = NSLocalizedString("max:", comment: "PlayerVC: max:")
    let avgStr = NSLocalizedString("avg:", comment: "PlayerVC: avg:")
    
    
    trackStatusLabel.text = "\(Int(distance)) \(mStr), \(timeString)\n\(minStr) \(Int(minSpeed)), \(maxStr) \(Int(maxSpeed)), \(avgStr) \(avgSpeed) \(unitSpeedStr)"
    
  }
  
  func showAlert() {
    let alert = UIAlertController(title: NSLocalizedString("Message", comment: "SettingVC Error-Title"), message: NSLocalizedString("For more pictures you need to go to Settings and buy Full Version", comment: "CameraVC Alert-Message"), preferredStyle: .alert)
    
    let cancelAction = UIAlertAction(title: NSLocalizedString("OK", comment: "CameraVC Alert-OK"), style: .default) { (action: UIAlertAction!) -> Void in
      //self.alertMaxVideo = false
    }
    
    alert.addAction(cancelAction)
    present(alert, animated: true, completion: nil)
  }

  
  // MARK: - Navigation
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    // print("prepareForSegue")
    if segue.identifier == "showMovie" {
      if let playerVC = segue.destination as? AVPlayerViewController {
        setupVariables()
        playerVC.player = player
        //playerVC.player?.play()
        playerVC.showsPlaybackControls = true
      }
    }
    if segue.identifier == "zoomSegue" {
      if let destVC = segue.destination as? ZoomedPhotoViewController {
        destVC.image = uiImage
      }
    }
  }
  
}

// MARK: - AVPlayerItemMetadataOutputPushDelegate

extension PlayerViewController: AVPlayerItemMetadataOutputPushDelegate {
  
  func metadataOutput(_ output: AVPlayerItemMetadataOutput, didOutputTimedMetadataGroups groups: [AVTimedMetadataGroup], from track: AVPlayerItemTrack) {
    // print("metadataOutput_didOutputTimedMetadataGroups")
    if playerMapMode != .distance {
      // Go through the list of timed metadata groups and update location
      for group in groups {
        if let newLocation = locationFromMetadataGroup(group) {
          location = newLocation
          updateCurrentLocation(newLocation)
        }
        var timeSpeedStr = ""
        if let timeStr = timeFromMetadataGroup(group) {
          timeSpeedStr += "\(timeStr)\n"
        }
        if let speedStr = speedFromMetadataGroup(group) {
          
          if speedStr.hasSuffix("mph") || speedStr.hasSuffix("km/h") || speedStr.hasSuffix("км/ч") {
            print("OLD DATA")
          } else {
            timeSpeedStr += distanceString(speedStr)
          }
        }
        DispatchQueue.main.async {
          self.trackStatusLabel.text = timeSpeedStr
        }
      }
    }
  }
}

// MARK: - MKMapViewDelegate

extension PlayerViewController: MKMapViewDelegate {
  
  func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
    // print("mapView_viewForAnnotation")
    
    var pin = mapView.dequeueReusableAnnotationView(withIdentifier: "currentPin")

    if pin == nil {
      pin = MKPinAnnotationView(annotation: annotation, reuseIdentifier: "currentPin")
      pin?.canShowCallout = true
    } else {
      pin?.annotation = annotation
    }
    
    return pin
  }
  
  func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
    // print("mapView_rendererForOverlay")
    
    let polylineRenderer = MKPolylineRenderer(overlay: overlay)
    polylineRenderer.lineWidth = 5.0
    if playerMapMode == .distance {
      polylineRenderer.strokeColor = UIColor(red: 0.2, green: 0.98, blue: 0.5, alpha: 0.8)
    } else {
      polylineRenderer.strokeColor = UIColor(red: 0.2, green: 0.5, blue: 0.98, alpha: 0.8)
    }
    
    return polylineRenderer
  }
}






