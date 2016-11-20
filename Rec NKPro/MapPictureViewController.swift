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
    mapTypeButton.layer.backgroundColor = UIColor(red: 176.0/255.0, green: 176.0/255.0, blue: 176.0/255.0, alpha: 0.5).cgColor
    
    navigationItem.title = NSLocalizedString("Map", comment: "MapPictureVC - Title")
    navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(MapPictureViewController.shareClicked))
    
    defineStackAxis()
    let notificationCenter = NotificationCenter.default
    notificationCenter.addObserver(self, selector: #selector(MapPictureViewController.defineStackAxis), name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
    
    mapView.delegate = self
    mapView.mapType = .standard
    loadData()
    mapView.addAnnotations(pictureLocations)
    if let index = pictureLocations.first?.pictureIndex {
      mapView.centerCoordinate = pictureLocations[0].coordinate
      updateCurrentLocation(index)
    }
    mapView.region = MKCoordinateRegionMakeWithDistance(mapView.centerCoordinate, 10000, 1000)
  }
  
  deinit {
    let notificationCenter = NotificationCenter.default
    notificationCenter.removeObserver(self, name: NSNotification.Name.UIDeviceOrientationDidChange, object: nil)
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }
  
  override var prefersStatusBarHidden : Bool {
    
    return true
  }
  
  @IBAction func changeMapType(_ sender: UIButton) {
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
  
  @IBAction func setPointOnMap(_ sender: UITapGestureRecognizer) {
    // print("TAP: setPointOnMap")
    if sender.state == .ended {
      let point = sender.location(in: mapView)
      let locCoord = mapView.convert(point, toCoordinateFrom: mapView)
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
        let dateString = dateStringFrom(picture.date as Date)
        var locationMessage = ""
        if let location = picture.location {
          locationMessage = coordinateStringFrom(location)
        }
        let message = dateString + picture.address + "\n" + locationMessage
        if let image = image {
          let activityVC = UIActivityViewController(activityItems: [message,image], applicationActivities: nil)
          activityVC.excludedActivityTypes = [UIActivityType.saveToCameraRoll]
          defer {
            self.present(activityVC, animated: true, completion: nil)
          }
        }
      }
    } else {
      showAlert()
    }
  }
  
  func dateStringFrom(_ date: Date) -> String {
    let dateFormater = DateFormatter()
    dateFormater.dateFormat = "yyyy/MM/dd HH:mm:ss"
    let timeString = dateFormater.string(from: date)
    return "\(timeString)\n"
  }
  
  func coordinateStringFrom(_ location: CLLocation) -> String {
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
    
    return "\(latitudeStr), \(longitudeStr)\n"
  }
  
  func showAlert() {
    
    let message = NSLocalizedString("For running this function you need to buy Full Version\n", comment: "SettingVC Error-Message") + IAPHelper.iapHelper.price
    
    let alert = UIAlertController(title: NSLocalizedString("Message", comment: "SettingVC Error-Title"), message: message, preferredStyle: .alert)
    
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
    self.present(alert, animated: true, completion: nil)
  }

  func defineStackAxis() {
    let orientation = UIDevice.current.orientation
    if orientation.isPortrait {
      mapPictureStack.axis = .vertical
    }
    if orientation.isLandscape {
      mapPictureStack.axis = .horizontal
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
  
  func updateCurrentLocation(_ index: Int) {
    // print("updateCurrentLocation")
    // Update current pin to the new location
    
    oldAnnotationIndex = currentAnnotationIndex
    var annotationIndex = 0
    for pLocation in pictureLocations {
      if pLocation.pictureIndex == index {
        mapView.setCenter(pLocation.coordinate, animated: true)
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
  
  func updateAnnotationView(_ index: Int?) {
    if let index = index {
      let annotation = pictureLocations[index]
      mapView.removeAnnotation(annotation)
      mapView.addAnnotation(annotation)
    }
  }
  
  func setNewPosition(_ newLocation: CLLocation) {
    var updatedPicture: PictureAnnotation? = nil
    var closestDistance: CLLocationDistance = DBL_MAX
    
    // Find the closest location on the path to which we can seek
    for pLocation in pictureLocations {
      let distance = newLocation.distance(from: pLocation.location!)
      if distance < closestDistance {
        updatedPicture = pLocation
        closestDistance = distance
      }
    }
    
    if let updatedPicture = updatedPicture {
      pageVC?.newIndex = updatedPicture.pictureIndex
      currentIndex = updatedPicture.pictureIndex
    }
  }
  
  
  // MARK: - Navigation
  
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    if segue.identifier == "picturePageSegue" {
      if let destVC = segue.destination as? PicturePageViewController {
        destVC.mainDelegate = self
        pageVC = destVC
      }
    }
  }
  
}

// MARK: - MKMapViewDelegate

extension MapPictureViewController: MKMapViewDelegate {
  
  func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
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
      var pinView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
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
