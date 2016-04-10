//
//  MapPictureViewController.swift
//  Rec NKPro
//
//  Created by NK on 07.04.16.
//  Copyright © 2016 Nikolay Kolesnikov. All rights reserved.
//

import UIKit
import MapKit

class MapPictureViewController: UIViewController, PicturePageViewControllerDelegate {
  
  @IBOutlet weak var mapPictureStack: UIStackView!
  @IBOutlet weak var mapView: MKMapView!
  @IBOutlet weak var mapTypeButton: UIButton!
  
  var currentIndex = 0 {
    didSet {
      //print("Current Index: \(currentIndex)")
      updateCurrentLocation(currentIndex)
    }
  }
  
  var pageVC: PicturePageViewController?
  
  var oldAnnotationIndex: Int?
  var currentAnnotationIndex: Int?
  
  var pictureLocations = [PictureAnnotation]()
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    mapTypeButton.layer.cornerRadius = 10
    mapTypeButton.layer.backgroundColor = UIColor(red: 176.0/255.0, green: 176.0/255.0, blue: 176.0/255.0, alpha: 0.5).CGColor
    
    navigationItem.title = NSLocalizedString("Map", comment: "MapPictureVC - Title")
    navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .Action, target: self, action: #selector(MapPictureViewController.shareClicked))
    
    defineStackAxis()
    let notificationCenter = NSNotificationCenter.defaultCenter()
    notificationCenter.addObserver(self, selector: #selector(MapPictureViewController.defineStackAxis), name: UIDeviceOrientationDidChangeNotification, object: nil)
    
    mapView.delegate = self
    mapView.mapType = .Standard
    loadData()
    mapView.addAnnotations(pictureLocations)
    if let index = pictureLocations.first?.pictureIndex {
      mapView.centerCoordinate = pictureLocations[0].coordinate
      updateCurrentLocation(index)
    }
    mapView.region = MKCoordinateRegionMakeWithDistance(mapView.centerCoordinate, 10000, 1000)
  }
  
  deinit {
    let notificationCenter = NSNotificationCenter.defaultCenter()
    notificationCenter.removeObserver(self, name: UIDeviceOrientationDidChangeNotification, object: nil)
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  override func prefersStatusBarHidden() -> Bool {
    
    return true
  }
  
  @IBAction func changeMapType(sender: UIButton) {
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
  
  @IBAction func setPointOnMap(sender: UITapGestureRecognizer) {
    // print("TAP: setPointOnMap")
    if sender.state == .Ended {
      let point = sender.locationInView(mapView)
      let locCoord = mapView.convertPoint(point, toCoordinateFromView: mapView)
      let newLocation = CLLocation(latitude: locCoord.latitude, longitude: locCoord.longitude)
      setNewPosition(newLocation)
    }
  }
  
  func shareClicked() {
    // print("shareClicked")
    if IAPHelper.iapHelper.setFullVersion {
      if PicturesList.pList.pictures.count != 0 {
        let picture = PicturesList.pList.pictures[currentIndex]
        let image = picture.loadImage()
        let dateString = dateStringFrom(picture.date)
        var locationMessage = ""
        if let location = picture.location {
          locationMessage = coordinateStringFrom(location)
        }
        let message = dateString + picture.address + "\n" + locationMessage + "\nhttp://nkpro.net"
        if let image = image {
          let activityVC = UIActivityViewController(activityItems: [message,image], applicationActivities: nil)
          activityVC.excludedActivityTypes = [UIActivityTypeSaveToCameraRoll]
          defer {
            self.presentViewController(activityVC, animated: true, completion: nil)
          }
        }
      }
    } else {
      showAlert()
    }
  }
  
  func dateStringFrom(date: NSDate) -> String {
    let dateFormater = NSDateFormatter()
    dateFormater.dateFormat = "yyyy/MM/dd HH:mm:ss"
    let timeString = dateFormater.stringFromDate(date)
    return "Date: \(timeString)\n"
  }
  
  func coordinateStringFrom(location: CLLocation) -> String {
    var latitudeStr = ""
    var longitudeStr = ""
    if location.coordinate.latitude >= 0 {
      latitudeStr = NSString(format: "N:%9.5lf", location.coordinate.latitude) as String
    } else {
      latitudeStr = NSString(format: "S:%9.5lf", -location.coordinate.latitude)  as String
    }
    
    if location.coordinate.longitude >= 0 {
      longitudeStr = NSString(format: "E:%9.5lf", location.coordinate.longitude) as String
    } else {
      longitudeStr = NSString(format: "W:%9.5lf", -location.coordinate.longitude)  as String
    }
    
    return "Location: \(latitudeStr), \(longitudeStr)\n"
  }
  
  func showAlert() {
    
    let message = NSLocalizedString("For running this function you need to go to Settings and buy Full Version", comment: "PictureVC FullVersion")
    
    let alert = UIAlertController(title: NSLocalizedString("Message", comment: "SettingVC Error-Title"), message: message, preferredStyle: .Alert)
    
    let cancelAction = UIAlertAction(title: NSLocalizedString("OK", comment: "SettingVC Error-OK"), style: .Default) { (action: UIAlertAction!) -> Void in
      
    }
    alert.addAction(cancelAction)
    self.presentViewController(alert, animated: true, completion: nil)
  }

  func defineStackAxis() {
    let orientation = UIDevice.currentDevice().orientation
    if orientation.isPortrait {
      mapPictureStack.axis = .Vertical
    }
    if orientation.isLandscape {
      mapPictureStack.axis = .Horizontal
    }
  }
  
  func loadData() {
    var index = 0
    for picture in PicturesList.pList.pictures {
      if let location = picture.location {
        let annotation = PictureAnnotation()
        annotation.location = location
        annotation.pictureIndex = index
        //print(index)
        annotation.title = picture.title
        pictureLocations.append(annotation)
      }
      index += 1
    }
  }
  
  func updateCurrentLocation(index: Int) {
    // print("updateCurrentLocation")
    // Update current pin to the new location
    
    oldAnnotationIndex = currentAnnotationIndex
    var annotationIndex = 0
    for pLocation in pictureLocations {
      if pLocation.pictureIndex == index {
        mapView.setCenterCoordinate(pLocation.coordinate, animated: true)
        currentAnnotationIndex = annotationIndex
        break
      } else {
        currentAnnotationIndex = nil
      }
      annotationIndex += 1
    }
    updateAnnotationView(oldAnnotationIndex)
    updateAnnotationView(currentAnnotationIndex)
  }
  
  func updateAnnotationView(index: Int?) {
    if let index = index {
      let annotation = pictureLocations[index]
      mapView.removeAnnotation(annotation)
      mapView.addAnnotation(annotation)
    }
  }
  
  func setNewPosition(newLocation: CLLocation) {
    var updatedPicture: PictureAnnotation? = nil
    var closestDistance: CLLocationDistance = DBL_MAX
    
    // Find the closest location on the path to which we can seek
    for pLocation in pictureLocations {
      let distance = newLocation.distanceFromLocation(pLocation.location!)
      if distance < closestDistance {
        updatedPicture = pLocation
        closestDistance = distance
      }
    }
    
    if let updatedPicture = updatedPicture {
      // TODO:
      
      pageVC?.newIndex = updatedPicture.pictureIndex
      currentIndex = updatedPicture.pictureIndex
    }
  }
  
  
  // MARK: - Navigation
  
  override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
    if segue.identifier == "picturePageSegue" {
      if let destVC = segue.destinationViewController as? PicturePageViewController {
        destVC.mainDelegate = self
        pageVC = destVC
      }
    }
  }
  
}

// MARK: - MKMapViewDelegate

extension MapPictureViewController: MKMapViewDelegate {
  
  func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
    // print("mapView_viewForAnnotation")
    
    if annotation is PictureAnnotation {
      
      var current = false
      var image: UIImage?
      if let pictureAnnotation = annotation as? PictureAnnotation {
        if pictureAnnotation.pictureIndex == currentIndex {
          image = UIImage(named: "CurStar")
          current = true
        } else {
          image = UIImage(named: "Star")
        }
      }
      let identifier = "starAnnotation"
      var pinView = mapView.dequeueReusableAnnotationViewWithIdentifier(identifier)
      if pinView == nil {
        
        //Create a plain MKAnnotationView if using a custom image...
        pinView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
        pinView?.canShowCallout = false
      }
      else {
        //Unrelated to the image problem but...
        //Update the annotation reference if re-using a view...
        pinView!.annotation = annotation
      }
      pinView!.image = image
      if current {
        pinView?.layer.zPosition = CGFloat(pictureLocations.count)
        //pinView?.superview?.bringSubviewToFront(pinView!)
      } else {
        pinView?.layer.zPosition = 0
        //pinView?.superview?.sendSubviewToBack(pinView!)
      }
      
      return pinView
    }
    return nil
    
  }
  
  
}
