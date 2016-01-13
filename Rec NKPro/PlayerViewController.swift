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

class PlayerViewController : UIViewController {
  
  enum MapMode : Int {
    case None = 0
    case Centered = 1
    case Distance = 2
  }
  
  var url: NSURL!
  var player: AVPlayer!
  var typeSpeed: TypeSpeed!
  
  // Reader variables
  private var reader: AVAssetReader!
  private var readerMetadataOutput: AVAssetReaderTrackOutput!
  private var metadataAdaptor: AVAssetReaderOutputMetadataAdaptor!
  private var readerQueue: dispatch_queue_t!
  
  // Output variable
  private var metadataOutput: AVPlayerItemMetadataOutput!
  
  // Location variables
  private var metadatas = [Metadata]()
  private var currentPin: MKPointAnnotation!
  private var playerMapMode: MapMode = .Centered
  private var startPoint: Metadata!
  private var endPoint: Metadata!
  private var distancePolyline: MKPolyline?
  
  @IBOutlet weak var mapView: MKMapView!
  @IBOutlet weak var playerStack: UIStackView!
  @IBOutlet weak var trackStatusLabel: UILabel!
  @IBOutlet weak var mapTypeButton: UIButton!
  @IBOutlet weak var centeredButton: UIButton!
  @IBOutlet weak var distanceButton: UIButton!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    mapTypeButton.layer.cornerRadius = 10
    mapTypeButton.layer.backgroundColor = UIColor(red: 176.0/255.0, green: 176.0/255.0, blue: 176.0/255.0, alpha: 0.5).CGColor
    
    //trackStatusLabel.layer.backgroundColor = UIColor(red: 176.0/255.0, green: 176.0/255.0, blue: 176.0/255.0, alpha: 0.5).CGColor
    //trackStatusLabel.layer.cornerRadius = 10.0
    
    self.centeredButton.enabled = false
    self.distanceButton.enabled = false
    
    defineStackAxis()
    let notificationCenter = NSNotificationCenter.defaultCenter()
    notificationCenter.addObserver(self, selector: "defineStackAxis", name: UIDeviceOrientationDidChangeNotification, object: nil)
    //notificationCenter.addObserver(self, selector: "didPlayToEndTime", name: AVPlayerItemDidPlayToEndTimeNotification, object: nil)
  }
  
  func didPlayToEndTime(){
    print("didPlayToEndTime")
  }
  
  func defineStackAxis() {
    let orientation = UIDevice.currentDevice().orientation
    if orientation.isPortrait {
      playerStack.axis = .Vertical
    }
    if orientation.isLandscape {
      playerStack.axis = .Horizontal
    }
  }
  
  deinit {
    let notificationCenter = NSNotificationCenter.defaultCenter()
    notificationCenter.removeObserver(self, name: UIDeviceOrientationDidChangeNotification, object: nil)
    player = nil
    url = nil
  }
  
  override func prefersStatusBarHidden() -> Bool {
    return true
  }
  
  func setupVariables() {
    print("setupVariables")
    
    // Initialize reader queue to perform all reading related operations on a background queue
    readerQueue = dispatch_queue_create("net.nkpro.fixdrive.reader.queue", DISPATCH_QUEUE_SERIAL)
    
    // Initialize metadata output with location identifier to get delegate callbacks with location metadata groups
    let metadataQueue = dispatch_queue_create("net.nkpro.fixdrive.metadata.queue", DISPATCH_QUEUE_SERIAL)
    
    metadataOutput = AVPlayerItemMetadataOutput(identifiers: [AVMetadataIdentifierQuickTimeMetadataLocationISO6709, FixdriveSpeedIdentifier, FixdriveTimeIdentifier])
    metadataOutput.setDelegate(self, queue: metadataQueue)
    
    setCentered()
    
    let asset = AVURLAsset(URL: url)
    let playerItem = AVPlayerItem(asset: asset)
    
    // Add metadata output to player item to get delegate callbacks during playback
    playerItem.addOutput(metadataOutput)
    
    player = AVPlayer(playerItem: playerItem)
    //player.videoGravity = AVLayerVideoGravityResizeAspect
    mapView.delegate = self
    mapView.mapType = .Standard
    
    readMetadataFromAsset(asset) { (metadataAvailable) -> Void in
      // Draw path on map only if we have location metadata
      if metadataAvailable {
        self.drawPathOnMap()
        self.trackStatusLabel.text = ""
        self.centeredButton.enabled = true
        self.distanceButton.enabled = true
      } else {
        //print("The input movie \(asset.URL) does not contain location metadata")
        self.trackStatusLabel.text = NSLocalizedString("No Data", comment: "PlayerVC: No Data")
      }
      self.player.play()
    }
  }
  
  // MARK: - Actions
    
  @IBAction func setPointOnMap(sender: UITapGestureRecognizer) {
    print("TAP: setPointOnMap")
    if sender.state == .Ended {
      let point = sender.locationInView(mapView)
      let locCoord = mapView.convertPoint(point, toCoordinateFromView: mapView)
      let newLocation = CLLocation(latitude: locCoord.latitude, longitude: locCoord.longitude)
      if playerMapMode == .Distance {
        setDistancePoint(newLocation)
      } else {
        userDidSeekToNewPosition(newLocation)
      }
    }
  }
  
  @IBAction func exit(sender: UIButton!) {
    player.pause()
    dismissViewControllerAnimated(false, completion: nil)
  }
  
  
  @IBAction func setMapType(sender: UIButton) {
    if mapView.mapType == .Standard {
      mapView.mapType = .Satellite
      mapTypeButton.setTitle(NSLocalizedString("Standard", comment: "PlayerVC: Standard"),
        forState: .Normal)
    } else {
      mapView.mapType = .Standard
      mapTypeButton.setTitle(NSLocalizedString("Satellite", comment: "PlayerVC: Satellite"),
        forState: .Normal)
    }
  }
  
  @IBAction func tapCenteredButton(sender: UIButton) {

    switch playerMapMode {
    case .None:
      playerMapMode = .Centered
      setCentered()
    case .Distance:
      playerMapMode = .Centered
      resetDistanceMode()
      setCentered()
    case .Centered:
      playerMapMode = .None
      setUncentered()
    }
    
  }
  
  @IBAction func tapDistanceButton(sender: UIButton) {
    switch playerMapMode {
    case .None:
      playerMapMode = .Distance
      setDistanceMode()
    case .Centered:
      playerMapMode = .Distance
      setUncentered()
      setDistanceMode()
    case .Distance:
      playerMapMode = .None
      resetDistanceMode()
    }
  }
  
  func setDistancePoint(newLocation: CLLocation) {
    var updatedMetadata: Metadata? = nil
    var closestDistance: CLLocationDistance = DBL_MAX
    
    // Find the closest location on the path to which we can seek
    for metadata in metadatas {
      let distance = newLocation.distanceFromLocation(metadata.location!)
      if distance < closestDistance {
        updatedMetadata = metadata
        closestDistance = distance
      }
    }
    
    let distanceToStart = updatedMetadata?.location?.distanceFromLocation(startPoint.location!)
    let distanceToEnd = updatedMetadata?.location?.distanceFromLocation(endPoint.location!)
    
    if distanceToStart < distanceToEnd {
      mapView.removeAnnotation(startPoint)
      startPoint = updatedMetadata
      mapView.addAnnotation(startPoint)
    } else {
      mapView.removeAnnotation(endPoint)
      endPoint = updatedMetadata
      mapView.addAnnotation(endPoint)
    }
    
    mapView.removeOverlay(distancePolyline!)
    
    if let startIndex = metadatas.indexOf(startPoint) {
      if let endIndex = metadatas.indexOf(endPoint) {
        dataFromPointsWithIndexes(startIndex: startIndex, endIndex: endIndex)
        
        var pointsToUse = [CLLocationCoordinate2D]()
        
        // Extract all the coordinates to draw from the locationPoints array
        for var i = startIndex; i <= endIndex; i++ {
          let metadata = metadatas[i]
          pointsToUse.append(metadata.coordinate)
        }
        
        // Draw the extracted path as an overlay on the map view
        distancePolyline = MKPolyline(coordinates: &pointsToUse, count: pointsToUse.count)
        mapView.addOverlay(distancePolyline!, level: .AboveRoads)
        
      }
    }
    
  }
  
  
  func userDidSeekToNewPosition(newLocation: CLLocation) {
    print("userDidSeekToNewPosition")
    
    var updatedMetadata: Metadata? = nil
    var closestDistance: CLLocationDistance = DBL_MAX
    
    // Find the closest location on the path to which we can seek
    for metadata in metadatas {
      let distance = newLocation.distanceFromLocation(metadata.location!)
      if distance < closestDistance {
        updatedMetadata = metadata
        closestDistance = distance
      }
    }
    
    if let updatedMetadata = updatedMetadata {
      dispatch_async(dispatch_get_main_queue(), { () -> Void in
        // Seek to timestamp of the updated location.
        let updatedTimeRange = updatedMetadata.timestamp!
        
        self.player.seekToTime(updatedTimeRange.start, completionHandler: { (finished) -> Void in
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
  
  func readMetadataFromAsset(asset: AVAsset, completionHandler: ((Bool) -> Void)) {
    print("readMetadataFromAsset")
    
    asset.loadValuesAsynchronouslyForKeys(["tracks"]) { () -> Void in
      // Dispatch all the reading work to a background queue, so we do not block the main thread
      dispatch_async(self.readerQueue, { () -> Void in
        var error: NSError?
        var success = (asset.statusOfValueForKey("tracks", error: &error) == .Loaded)
        
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
        dispatch_async(dispatch_get_main_queue()) { () -> Void in
          completionHandler(metadataAvailable)
        }
      })
    }
  }
  
  func setUpReaderForAsset(asset: AVAsset) -> Bool {
    print("setUpReaderForAsset")
    
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
      let metadataTracks = asset.tracksWithMediaType(AVMediaTypeMetadata)
      for track in metadataTracks {
        
        for formatDescription in track.formatDescriptions {
          // Check if the format description for the track contains location identifier
          
          var identifiers: NSArray? = nil
          
          identifiers = CMMetadataFormatDescriptionGetIdentifiers(formatDescription as! CMMetadataFormatDescription)
          
          if let identifiers = identifiers {
            if identifiers.containsObject(AVMetadataIdentifierQuickTimeMetadataLocationISO6709) {
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
      reader.addOutput(readerMetadataOutput)
    }
    
    return success
  }
  
  func startReadingLocationMetadata() -> Bool {
    print("startReadingLocationMetadata")
    
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
      print("ERROR: startReadingLocationMetadata - \(player.error?.userInfo)")
    }
    
    return success
  }
  
  // MARK: - Utilites
  
  func drawPathOnMap() {
    print("drawPathOnMap")
    
    let numberOfPoints = metadatas.count
    var pointsToUse = [CLLocationCoordinate2D](count: numberOfPoints, repeatedValue: CLLocationCoordinate2D())
    
    // Extract all the coordinates to draw from the locationPoints array
    for var i = 0; i < numberOfPoints; i++ {
      let metadata = metadatas[i]
      pointsToUse[i] = metadata.location!.coordinate
    }
    
    // Draw the extracted path as an overlay on the map view
    let polyline = MKPolyline(coordinates: &pointsToUse, count: numberOfPoints)
    mapView.addOverlay(polyline, level: .AboveRoads)
    
    // Set initial coordinate to the starting coordinate of the path
    mapView.centerCoordinate = metadatas.first!.location!.coordinate
    
    var distance: Double = 0.0
    
    if numberOfPoints > 0 {
      distance = max(metadatas.first!.location!.distanceFromLocation(metadatas.last!.location!) * 1.5, 800.0)
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
    
    if let startIndex = metadatas.indexOf(startPoint) {
      if let endIndex = metadatas.indexOf(endPoint) {
        dataFromPointsWithIndexes(startIndex: startIndex, endIndex: endIndex)
        
        var pointsToUse = [CLLocationCoordinate2D]()
        
        // Extract all the coordinates to draw from the locationPoints array
        for var i = startIndex; i < endIndex; i++ {
          let metadata = metadatas[i]
          pointsToUse.append(metadata.coordinate)
        }
        
        // Draw the extracted path as an overlay on the map view
        distancePolyline = MKPolyline(coordinates: &pointsToUse, count: pointsToUse.count)
        mapView.addOverlay(distancePolyline!, level: .AboveRoads)
    
      }
    }
    
  }
  
  
  func removeDistancePath() {
    mapView.removeOverlay(distancePolyline!)
    mapView.removeAnnotations([startPoint, endPoint])
    mapView.addAnnotation(currentPin)
  }
  
  func locationFromMetadataGroup(group: AVTimedMetadataGroup) -> CLLocation? {
    print("locationFromMetadataGroup")
    
    var location: CLLocation? = nil
    
    // Go through the timed metadata group to extract location value
    for item in group.items {
      // Check to see if the item's data type matches quick time metadata location data type
      
      if let itemString = item.identifier {
        if itemString == AVMetadataIdentifierQuickTimeMetadataLocationISO6709 {
          if let locationDescription = item.stringValue {
            // Extract from a string in iso6709 notation
            let latitude = (locationDescription as NSString).substringToIndex(8)
            let longitude = (locationDescription as NSString).substringWithRange(NSMakeRange(8, 9))
            location = CLLocation(latitude: (latitude as NSString).doubleValue, longitude: (longitude as NSString).doubleValue)
          }
         break
        }
      }
    }
    
    return location
  }
  
  func speedFromMetadataGroup(group: AVTimedMetadataGroup) -> String? {
    print("speedFromMetadataGroup")
    
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
  
  func timeFromMetadataGroup(group: AVTimedMetadataGroup) -> String? {
    print("timeFromMetadataGroup")
    
    var time: String? = nil
    
    // Go through the timed metadata group to extract location value
    for item in group.items {
      // Check to see if the item's data type matches quick time metadata location data type
      
      if let itemString = item.identifier {
        if itemString == FixdriveTimeIdentifier {
          if let timeDescription = item.stringValue {
            time = timeDescription
            //print("Time: \(timeDescription)")
          }
          break
        }
      }
    }
    return time
  }
  
  
  
  func updateCurrentLocation(location: CLLocation) {
    print("updateCurrentLocation")
    // Update current pin to the new location
    dispatch_async(dispatch_get_main_queue()) { () -> Void in
      if let currentPin = self.currentPin {
        currentPin.coordinate = location.coordinate
        if self.playerMapMode == .Centered {
          self.mapView.setCenterCoordinate(currentPin.coordinate, animated: true)
          self.mapView.addAnnotation(currentPin)
        }
      }
    }
  }
  
  func setCentered() {
    print("setCentered")
    centeredButton.setImage(UIImage(named: "CenteredHi"), forState: .Normal)
    dispatch_async(dispatch_get_main_queue()) { () -> Void in
      if let currentPin = self.currentPin {
        self.mapView.setCenterCoordinate(currentPin.coordinate, animated: true)
      }
    }
  }
  
  func setUncentered() {
    print("setUncentered")

    centeredButton.setImage(UIImage(named: "Centered"), forState: .Normal)
  }
  
  func setDistanceMode() {
    distanceButton.setImage(UIImage(named: "DistanceHi"), forState: .Normal)
    
    drawDistancePath()
  }
  
  func resetDistanceMode() {
    distanceButton.setImage(UIImage(named: "Distance"), forState: .Normal)
    trackStatusLabel.text = ""
    removeDistancePath()
  }
  
  func distanceString(distance: String) -> String {
    var unitSpeedStr = ""
    var kSpeed: Float = 0
    
    let mphStr = NSLocalizedString("mph", comment: "PlayerVC: mph")
    let kmhStr = NSLocalizedString("km/h", comment: "PlayerVC: km/h")
    
    if typeSpeed == .Mi {
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
  
  func dataFromPointsWithIndexes(startIndex startIndex: Int, endIndex: Int) {
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
    
    if typeSpeed == .Mi {
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
      index++
      let delta = metadata.location!.distanceFromLocation(metadatas[index].location!)
      if delta > 20 {
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

  
  // MARK: - Navigation
  override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
    print("prepareForSegue")
    if segue.identifier == "showMovie" {
      let playerVC = segue.destinationViewController as! AVPlayerViewController
      setupVariables()
      playerVC.player = player
      //playerVC.player?.play()
      playerVC.showsPlaybackControls = true
    }
  }
  
}

// MARK: - AVPlayerItemMetadataOutputPushDelegate

extension PlayerViewController: AVPlayerItemMetadataOutputPushDelegate {
  
  func metadataOutput(output: AVPlayerItemMetadataOutput, didOutputTimedMetadataGroups groups: [AVTimedMetadataGroup], fromPlayerItemTrack track: AVPlayerItemTrack) {
    print("metadataOutput_didOutputTimedMetadataGroups")
    if playerMapMode != .Distance {
      // Go through the list of timed metadata groups and update location
      for group in groups {
        if let newLocation = locationFromMetadataGroup(group) {
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
        dispatch_async(dispatch_get_main_queue()) {
          self.trackStatusLabel.text = timeSpeedStr
        }
      }
    }
  }
}

// MARK: - MKMapViewDelegate

extension PlayerViewController: MKMapViewDelegate {
  
  func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
    print("mapView_viewForAnnotation")
    
    var pin = mapView.dequeueReusableAnnotationViewWithIdentifier("currentPin")

    if pin == nil {
      pin = MKPinAnnotationView(annotation: annotation, reuseIdentifier: "currentPin")
    } else {
      pin?.annotation = annotation
      pin?.canShowCallout = true
    }
    
    return pin
  }
  
  func mapView(mapView: MKMapView, rendererForOverlay overlay: MKOverlay) -> MKOverlayRenderer {
    print("mapView_rendererForOverlay")
    
    let polylineRenderer = MKPolylineRenderer(overlay: overlay)
    polylineRenderer.lineWidth = 5.0
    if playerMapMode == .Distance {
      polylineRenderer.strokeColor = UIColor(red: 0.2, green: 0.98, blue: 0.5, alpha: 0.8)
    } else {
      polylineRenderer.strokeColor = UIColor(red: 0.2, green: 0.5, blue: 0.98, alpha: 0.8)
    }
    
    return polylineRenderer
  }
}






