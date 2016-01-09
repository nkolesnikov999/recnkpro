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
  
  var url: NSURL!
  var player: AVPlayer!
  
  // Reader variables
  private var reader: AVAssetReader!
  private var readerMetadataOutput: AVAssetReaderTrackOutput!
  private var metadataAdaptor: AVAssetReaderOutputMetadataAdaptor!
  private var readerQueue: dispatch_queue_t!
  
  // Output variable
  private var metadataOutput: AVPlayerItemMetadataOutput!
  
  // Location variables
  private var locationPoints = [CLLocation]()
  private var timeStamps = [CMTimeRange]()
  private var currentPin: MKPointAnnotation!
  private var shouldCenterMapView = false
  
  @IBOutlet weak var mapView: MKMapView!
  @IBOutlet weak var playerStack: UIStackView!
  @IBOutlet weak var trackStatusLabel: UILabel!
  @IBOutlet weak var mapTypeButton: UIButton!
  @IBOutlet weak var centeredButton: UIButton!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    mapTypeButton.layer.cornerRadius = 10
    mapTypeButton.layer.backgroundColor = UIColor(red: 176.0/255.0, green: 176.0/255.0, blue: 176.0/255.0, alpha: 0.5).CGColor
    
    trackStatusLabel.layer.backgroundColor = UIColor(red: 176.0/255.0, green: 176.0/255.0, blue: 176.0/255.0, alpha: 0.5).CGColor
    trackStatusLabel.layer.cornerRadius = 10.0
    
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
      } else {
        //print("The input movie \(asset.URL) does not contain location metadata")
        self.trackStatusLabel.text = NSLocalizedString("No Data", comment: "PlayerVC: No Data")
        self.centeredButton.enabled = false
      }
      self.player.play()
    }
  }
  
  // MARK: - Actions
  
  @IBAction func draggedAction(sender: UIPanGestureRecognizer) {
    // Stop centering the map since the user started dragging the map around.
    // We do not center the map until the user seeks to some location
    setUncentered()
  }
  
  @IBAction func pinchAction(sender: UIPinchGestureRecognizer) {
    // Stop centering the map since the user started dragging the map around.
    // We do not center the map until the user seeks to some location
    setUncentered()
  }
  
  @IBAction func setPointOnMap(sender: UITapGestureRecognizer) {
    print("TAP: setPointOnMap")
    if sender.state == .Ended {
      let point = sender.locationInView(mapView)
      let locCoord = mapView.convertPoint(point, toCoordinateFromView: mapView)
      let newLocation = CLLocation(latitude: locCoord.latitude, longitude: locCoord.longitude)
      userDidSeekToNewPosition(newLocation)
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
    
    if shouldCenterMapView {
      setUncentered()
    } else {
      setCentered()
    }
    
  }
  
  
  
  func userDidSeekToNewPosition(newLocation: CLLocation) {
    print("userDidSeekToNewPosition")
    
    var updatedLocation: CLLocation? = nil
    var closestDistance: CLLocationDistance = DBL_MAX
    
    // Find the closest location on the path to which we can seek
    for location in locationPoints {
      let distance = newLocation.distanceFromLocation(location)
      if distance < closestDistance {
        updatedLocation = location
        closestDistance = distance
      }
    }
    
    if let updatedLocation = updatedLocation {
      dispatch_async(dispatch_get_main_queue(), { () -> Void in
        // Seek to timestamp of the updated location.
        let updatedTimeRange = self.timeStamps[self.locationPoints.indexOf(updatedLocation)!]
        self.player.seekToTime(updatedTimeRange.start, completionHandler: { (finished) -> Void in
          // Start centering the map at the current location
          self.setCentered()
          // Move the pin to updated location.
          if finished {
            self.updateCurrentLocation(updatedLocation)
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
          metadataAvailable = self.locationPoints.count > 0
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
          locationPoints.append(location)
          timeStamps.append(group!.timeRange)
        }
        group = metadataAdaptor.nextTimedMetadataGroup()
      }
    } else {
      print("ERROR: startReadingLocationMetadata - \(player.error?.userInfo)")
    }
    
    return success
  }
  
  // MARK: - Utilites
  
  func drawPathOnMap() {
    print("drawPathOnMap")
    
    let numberOfPoints = locationPoints.count
    var pointsToUse = [CLLocationCoordinate2D](count: numberOfPoints, repeatedValue: CLLocationCoordinate2D())
    
    // Extract all the coordinates to draw from the locationPoints array
    for var i = 0; i < numberOfPoints; i++ {
      let location = locationPoints[i]
      pointsToUse[i] = location.coordinate
    }
    
    // Draw the extracted path as an overlay on the map view
    let polyline = MKPolyline(coordinates: &pointsToUse, count: numberOfPoints)
    mapView.addOverlay(polyline, level: .AboveRoads)
    
    // Set initial coordinate to the starting coordinate of the path
    mapView.centerCoordinate = locationPoints.first!.coordinate
    
    var distance: Double = 0.0
    
    if numberOfPoints > 0 {
      distance = max(locationPoints.first!.distanceFromLocation(locationPoints.last!) * 1.5, 800.0)
    }
    
    // Set initial region to some region around the starting coordinate
    mapView.region = MKCoordinateRegionMakeWithDistance(mapView.centerCoordinate, distance, distance)
    
    currentPin = MKPointAnnotation()
    currentPin.coordinate = mapView.centerCoordinate
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
        if self.shouldCenterMapView {
          self.mapView.setCenterCoordinate(currentPin.coordinate, animated: true)
          self.mapView.addAnnotation(currentPin)
        }
      }
    }
  }
  
  func setCentered() {
    print("setCentered")
    shouldCenterMapView = true
    centeredButton.setImage(UIImage(named: "CenteredHi"), forState: .Normal)
    dispatch_async(dispatch_get_main_queue()) { () -> Void in
      if let currentPin = self.currentPin {
        if self.shouldCenterMapView {
          self.mapView.setCenterCoordinate(currentPin.coordinate, animated: true)
        }
      }
    }
  }
  
  func setUncentered() {
    print("setUncentered")
    shouldCenterMapView = false
    centeredButton.setImage(UIImage(named: "Centered"), forState: .Normal)
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
        timeSpeedStr += speedStr
      }
      dispatch_async(dispatch_get_main_queue()) {
        self.trackStatusLabel.text = timeSpeedStr
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
    }
    
    return pin
  }
  
  func mapView(mapView: MKMapView, rendererForOverlay overlay: MKOverlay) -> MKOverlayRenderer {
    print("mapView_rendererForOverlay")
    
    let polylineRenderer = MKPolylineRenderer(overlay: overlay)
    polylineRenderer.strokeColor = UIColor(red: 0.1, green: 0.5, blue: 0.98, alpha: 0.8)
    polylineRenderer.lineWidth = 5.0
    
    return polylineRenderer
  }
}






