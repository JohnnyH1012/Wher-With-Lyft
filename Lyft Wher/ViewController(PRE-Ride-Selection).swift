//
//  ViewController.swift
//  Lyft Wher
//
//  Created by John Harding on 9/8/17.
//  Copyright © 2017 John Harding. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import LyftSDK
import CoreLocation
import MapKit

class ViewController: UIViewController, ARSCNViewDelegate, CLLocationManagerDelegate, SceneLocationViewDelegate, MKMapViewDelegate, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate, UISearchDisplayDelegate {

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var lyftButton: LyftButton!
    @IBOutlet weak var settingsEffectView: UIVisualEffectView!
    @IBOutlet weak var lyftEffectView: UIVisualEffectView!
    @IBOutlet weak var lyftIcon: UIButton!
    let manager = CLLocationManager()
    var userLocation = CLLocation()
    let sceneLocationView = SceneLocationView()
    let mapView = MKMapView()
    var userAnnotation: MKPointAnnotation?
    var locationEstimateAnnotation: MKPointAnnotation?
    var carTypes = [String]()
    var etas = [String]()
    var seats = [String]()
    var entityNames = [String]()
    var entityCoords = [[Double]]()
    var updateUserLocationTimer: Timer?
    var updateDriverLocationTimer: Timer?
    var previousDestinationNode: LocationAnnotationNode?
    var allNodes = [LocationAnnotationNode]()
    var isFirstRun: Bool = true

    var showMapView: Bool = false
    var centerMapOnUserLocation: Bool = true
    
    ///Whether to display some debugging data
    ///This currently displays the coordinate of the best location estimate
    ///The initial value is respected
    var displayDebugging = true
    
    var infoLabel = UILabel()
    
    var updateInfoLabelTimer: Timer?
    
    var adjustNorthByTappingSidesOfScreen = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //Setup All Present Views
        drawViews()
        self.lyftButton.style = .multicolor
        self.lyftButton.deepLinkBehavior = LyftDeepLinkBehavior.native
        
        //Setup Location Manager
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
        
        // Set the view's delegate
        //sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        //sceneView.showsStatistics = true
        
        // Create a new scene
        //let scene = SCNScene(named: "art.scnassets/ship.scn")!
        
        // Set the scene to the view
        //sceneView.scene = scene
        sceneLocationView.showAxesNode = false
        sceneLocationView.locationDelegate = self
        
        if displayDebugging {
            sceneLocationView.showFeaturePoints = false
        }

        view.addSubview(sceneLocationView)
        
        
        
        
        if showMapView {
            mapView.delegate = self
            mapView.showsUserLocation = true
            mapView.alpha = 0.8
            view.addSubview(mapView)
            
            
            updateUserLocationTimer = Timer.scheduledTimer(
                timeInterval: 0.5,
                target: self,
                selector: #selector(ViewController.updateUserLocation),
                userInfo: nil,
                repeats: true)
            
            
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()

        // Run the view's session
        //sceneView.session.run(configuration)
        sceneLocationView.run()
    }
    
    override func viewDidLayoutSubviews() {
        sceneLocationView.frame = CGRect(
            x: 0,
            y: 0,
            width: self.view.frame.size.width,
            height: self.view.frame.size.height)
        
        mapView.frame = CGRect(
            x: 0,
            y: self.view.frame.size.height / 2,
            width: self.view.frame.size.width,
            height: self.view.frame.size.height / 2)
        
        //view.sendSubview(toBack: tableView)
        view.bringSubview(toFront: settingsEffectView)
        view.bringSubview(toFront: lyftEffectView)
        view.bringSubview(toFront: lyftButton)
        view.bringSubview(toFront: lyftIcon)
        if isFirstRun {
            presentLoadingView()
            isFirstRun = false
        }
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        //sceneView.session.pause()
        sceneLocationView.pause()
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        print("ecc",self.entityCoords.count);print("enc",self.entityNames.count)
        return self.entityCoords.count
        
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        print("i",indexPath.row)
        print("ennts",entityNames.count,"encs",entityCoords.count)
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell")
        cell?.textLabel?.text = entityNames[indexPath.row]
        
         let coordinateBusiness = CLLocation(latitude: entityCoords[indexPath.row][0], longitude: entityCoords[indexPath.row][1])
        let distanceInMiles = userLocation.distance(from: coordinateBusiness) / 1609.34
        cell?.detailTextLabel?.text = "\((distanceInMiles * 10).rounded() / 10) Miles"
        return cell!
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if previousDestinationNode != nil {
            self.sceneLocationView.removeLocationNode(locationNode: previousDestinationNode!)
        }
        view.sendSubview(toBack: self.tableView)
        let factoryImage = self.imageFactoryProduceDestination(location: CLLocationCoordinate2D(latitude:entityCoords[indexPath.row][0],longitude: entityCoords[indexPath.row][1]), destinationName: entityNames[indexPath.row])
        let annotationNode = LocationAnnotationNode(location: CLLocation(latitude:entityCoords[indexPath.row][0],longitude:entityCoords[indexPath.row][1]), image: factoryImage)
            previousDestinationNode = annotationNode
        let destination = CLLocationCoordinate2D(latitude:entityCoords[indexPath.row][0],longitude:entityCoords[indexPath.row][1])
        lyftButton.configure(pickup: userLocation.coordinate, destination: destination)
        self.sceneLocationView.addLocationNodeWithConfirmedLocation(locationNode: annotationNode)
    }
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        view.bringSubview(toFront: self.tableView)
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText != "" {
            view.bringSubview(toFront: self.tableView)
            getPlacesInBetween(requestedQuery: searchText)
        }
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        view.sendSubview(toBack: self.tableView)
    }
    
    func getPlacesInBetween(requestedQuery: String) {
        entityCoords = [];entityNames = []
        let request = MKLocalSearchRequest()
        request.naturalLanguageQuery = requestedQuery
        // 2
        let newSpan = MKCoordinateRegionMakeWithDistance(userLocation.coordinate, 50.0 * 1609.34, 50.0 * 1609.34)
        request.region = MKCoordinateRegion(center: userLocation.coordinate, span: newSpan.span)
        // 3
        let search = MKLocalSearch(request: request)
        search.start(completionHandler: {(response, error) in
            print("RIE:",(response?.mapItems)!.enumerated())
            for (i,item) in (response?.mapItems)!.enumerated() {
                print(item.name!,[item.placemark.coordinate.latitude,item.placemark.coordinate.longitude])
                //let annotation = MKPointAnnotation()
                //annotation.coordinate = item.placemark.coordinate
                //annotation.title = item.name
                self.entityNames.append(item.name!)

                self.entityCoords.append([item.placemark.coordinate.latitude,item.placemark.coordinate.longitude])
                if i == (response?.mapItems.count)! - 1 {
                    self.tableView.reloadData()
                }
            }
        })
    }
    
    func drawViews() {
        lyftButton.layer.cornerRadius = 6
        tableView.layer.cornerRadius  = 5
        settingsEffectView.layer.cornerRadius = 5
        lyftEffectView.layer.cornerRadius = 5
        lyftButton.clipsToBounds = true
        settingsEffectView.clipsToBounds = true
        tableView.clipsToBounds = true
        lyftEffectView.clipsToBounds = true
        let textFieldInsideSearchBar = searchBar.value(forKey: "searchField") as? UITextField
        textFieldInsideSearchBar?.textColor = UIColor.white
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }
    
    func orderRides(completion: @escaping (_ result: Bool) -> ()) {
        var i = 0
        let location = CLLocationCoordinate2D(latitude: userLocation.coordinate.latitude, longitude: userLocation.coordinate.longitude)
        LyftAPI.ETAs(to: location) { result in
            result.value?.forEach { eta in
                print("ETA",eta)
                self.etas.append("\(eta.minutes) mins")
                LyftAPI.rideTypes(at: location) { result in
                    result.value?.forEach { rideType in
                        print("RV:",rideType.kind.rawValue)
                        if (rideType.kind.rawValue) == "lyft" {
                            self.carTypes.append("Standard")
                            self.seats.append("\(rideType.numberOfSeats)")
                        } else if (rideType.kind.rawValue).split(separator: "_")[1] == "plus" {
                            self.carTypes.append("Plus")
                            self.seats.append("\(rideType.numberOfSeats)")
                        } else if (rideType.kind.rawValue).split(separator: "_")[1] == "line" {
                            self.carTypes.append("Line")
                            self.seats.append("1")
                        } else if (rideType.kind.rawValue).split(separator: "_")[1] == "lux" {
                            self.carTypes.append("Lux")
                            self.seats.append("\(rideType.numberOfSeats)")
                        }
                        if i == (((result.value?.count)! - 1)) {
                            print("i",i,"rsvc",(result.value?.count)! - 1)
                            completion(true)
                        }
                        i = i + 1
                    }
                }
            }
        }
    }
    
    @objc func getRideLocations() {
        let location = CLLocationCoordinate2D(latitude: userLocation.coordinate.latitude, longitude: userLocation.coordinate.longitude)
        print("uL",userLocation)
        LyftAPI.drivers(near: location) { result in
            var i = 0
            print("Lyft Plus drivers most recent positions:")
            let nearbyDrivers = result.value?[]
            print("nearbyDrivers:\(nearbyDrivers)")
            nearbyDrivers?.forEach { driver in
                print("ACTING FOR EACH DRIVER")
                 /*self.updateDriverLocationTimer = Timer.scheduledTimer(
                 timeInterval: 5.0,
                 target: self,
                 selector: #selector(ViewController.resetAndGetRideLocations),
                 userInfo: nil,
                 repeats: true) */
                let coordinate = CLLocationCoordinate2D(latitude: driver.position!.latitude, longitude: driver.position!.longitude)
                let location = CLLocation(coordinate: coordinate, altitude: self.userLocation.altitude)
                print("seats",self.seats,"eta",self.etas)
                if self.seats.indices.contains(i) && self.etas.indices.contains(i) && self.carTypes.indices.contains(i){
                    let factoryImage = self.imageFactoryProduceDrivers(location: coordinate, seats: self.seats[i], type: self.carTypes[i], eta: self.etas[i])
                    let annotationNode = LocationAnnotationNode(location: location, image: factoryImage)
                    self.allNodes.append(annotationNode)
                    self.sceneLocationView.addLocationNodeWithConfirmedLocation(locationNode: annotationNode)
                     i = i + 1
                } else {
                   let factoryImage = self.imageFactoryProduceDrivers(location: coordinate, seats: "3", type: "Standard", eta: self.etas[1])
                    let annotationNode = LocationAnnotationNode(location: location, image: factoryImage)
                    self.allNodes.append(annotationNode)
                    self.sceneLocationView.addLocationNodeWithConfirmedLocation(locationNode: annotationNode)
                     i = i + 1
                }
            }
        }
    }
    
    func resetAndOrderRides(completion: @escaping (_ result: Bool) -> ()) {
       
    }
    
    @objc func resetAndGetRideLocations() {
        let location = CLLocationCoordinate2D(latitude: userLocation.coordinate.latitude, longitude: userLocation.coordinate.longitude)
        var i = 0
        seats = [];etas = []; carTypes = [];
        LyftAPI.ETAs(to: location) { result in
            result.value?.forEach { eta in
                print("ETA",eta)
                self.etas.append("\(eta.minutes) mins")
                LyftAPI.rideTypes(at: location) { result in
                    result.value?.forEach { rideType in
                        print("RV:",rideType.kind.rawValue)
                        if (rideType.kind.rawValue) == "lyft" {
                            self.carTypes.append("Standard")
                            self.seats.append("\(rideType.numberOfSeats)")
                        } else if (rideType.kind.rawValue).split(separator: "_")[1] == "plus" {
                            self.carTypes.append("Plus")
                            self.seats.append("\(rideType.numberOfSeats)")
                        } else if (rideType.kind.rawValue).split(separator: "_")[1] == "line" {
                            self.carTypes.append("Line")
                            self.seats.append("1")
                        } else if (rideType.kind.rawValue).split(separator: "_")[1] == "lux" {
                            self.carTypes.append("Lux")
                            self.seats.append("\(rideType.numberOfSeats)")
                        }
                        
                        if i == (((result.value?.count)! - 1)) {
                            LyftAPI.drivers(near: location) { result in
                                var i = 0
                                print("Lyft Plus drivers most recent positions:")
                                let nearbyDrivers = result.value?[RideKind.Standard]
                                if nearbyDrivers != nil {
                                    for (index,driver) in self.allNodes.enumerated() {
                                        self.sceneLocationView.removeLocationNode(locationNode: driver)
                                        print("indexx:",index,"sanc",self.allNodes.count - 1)
                                        if index == self.allNodes.count - 1 {
                                            self.allNodes = [];        //Clear all Variables before we start again
                                            nearbyDrivers?.forEach { driver in
                                                print("for each driver")
                                                let coordinate = CLLocationCoordinate2D(latitude: driver.position!.latitude, longitude: driver.position!.longitude)
                                                let location = CLLocation(coordinate: coordinate, altitude: self.userLocation.altitude)
                                                if self.seats.indices.contains(i) && self.etas.indices.contains(i) && self.carTypes.indices.contains(i){
                                                    let factoryImage = self.imageFactoryProduceDrivers(location: coordinate, seats: self.seats[i], type: self.carTypes[i], eta: self.etas[i])
                                                    let annotationNode = LocationAnnotationNode(location: location, image: factoryImage)
                                                    self.allNodes.append(annotationNode)
                                                    self.sceneLocationView.addLocationNodeWithConfirmedLocation(locationNode: annotationNode)
                                                    i = i + 1
                                                } else {
                                                    let factoryImage = self.imageFactoryProduceDrivers(location: coordinate, seats: "3", type: "Standard", eta: self.etas[1])
                                                    let annotationNode = LocationAnnotationNode(location: location, image: factoryImage)
                                                    self.allNodes.append(annotationNode)
                                                    self.sceneLocationView.addLocationNodeWithConfirmedLocation(locationNode: annotationNode)
                                                    i = i + 1
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        i = i + 1
                    }
                }
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            print("Found user's location: \(location)")
            userLocation = location
            orderRides() { (boolValue) in
                self.getRideLocations()
            }
            //let pickup = CLLocationCoordinate2D(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
            dismiss(animated: true, completion: nil)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Failed to find user's location: \(error.localizedDescription)")
    }
    
    func presentLoadingView(){
        let alert = UIAlertController(title: nil, message: "Getting Location", preferredStyle: .alert)
        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyle.gray
        loadingIndicator.startAnimating();
        alert.view.addSubview(loadingIndicator)
        print("lvpresented")
        self.present(alert, animated: true, completion: nil)
        
    }
    
    func imageFactoryProduceDrivers(location: CLLocationCoordinate2D, seats: String, type: String, eta: String) -> UIImage {
        print("imagefactory produced image")
        var pinImage = UIImage()
        if type == "Standard" {
            pinImage = UIImage(named: "pin")!
            pinImage = self.textToImage(theText: "\(type) | \(seats)", inImage: pinImage, atPoint: CGPoint(x: 54, y: 120))
        } else if type == "Line" {
            pinImage = UIImage(named: "pin")!
            pinImage = self.textToImage(theText: "\(type) | \(seats)", inImage: pinImage, atPoint: CGPoint(x: 64, y: 120))
        } else if type == "Plus" {
            pinImage = UIImage(named: "pinPlus")!
            pinImage = self.textToImage(theText: "\(type) | \(seats)", inImage: pinImage, atPoint: CGPoint(x: 65, y: 120))
        } else if type == "Lux" {
            pinImage = UIImage(named: "pinLux")!
            pinImage = self.textToImage(theText: "\(type) | \(seats)", inImage: pinImage, atPoint: CGPoint(x: 65, y: 120))
        }
        
        pinImage = self.textToImageCoords(coordinate: location , inImage: pinImage, atPoint: CGPoint(x: 58, y: 20))
        
        pinImage = self.textToImage(theText: "\(eta)", inImage: pinImage, atPoint: CGPoint(x: 65, y: 140))
        return pinImage
    }
    
    func imageFactoryProduceDestination(location: CLLocationCoordinate2D, destinationName: String) -> UIImage {
        var pinImage = UIImage(named: "pinDest")!
        pinImage = self.textToImageCoords(coordinate: location , inImage: pinImage, atPoint: CGPoint(x: 58, y: 20))
        pinImage = self.textToImage(theText: destinationName, inImage: pinImage, atPoint: CGPoint(x: 45, y: 150))
        return pinImage
    }
    
    func textToImageCoords(coordinate coord: CLLocationCoordinate2D, inImage image: UIImage, atPoint point: CGPoint) -> UIImage {
        let textColor = UIColor.white
        let textFont = UIFont(name: "Helvetica Neue", size: 18)!
        let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        let text = determineDistanceFromUser(driverLocation: location)
        let scale = UIScreen.main.scale
        UIGraphicsBeginImageContextWithOptions(image.size, false, scale)
        
        let textFontAttributes = [
            NSAttributedStringKey.font: textFont,
            NSAttributedStringKey.foregroundColor: textColor,
            ] as [NSAttributedStringKey : Any]
        image.draw(in: CGRect(origin: CGPoint.zero, size: image.size))
        
        let rect = CGRect(origin: point, size: image.size)
        text.draw(in: rect, withAttributes: textFontAttributes)
        
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage!
    }
    
    func textToImage(theText text: String, inImage image: UIImage, atPoint point: CGPoint) -> UIImage {
        let textColor = UIColor.white
        let textFont = UIFont(name: "Helvetica Neue", size: 18)!
        let scale = UIScreen.main.scale
        UIGraphicsBeginImageContextWithOptions(image.size, false, scale)
        
        let textFontAttributes = [
            NSAttributedStringKey.font: textFont,
            NSAttributedStringKey.foregroundColor: textColor,
            ] as [NSAttributedStringKey : Any]
        image.draw(in: CGRect(origin: CGPoint.zero, size: image.size))
        
        let rect = CGRect(origin: point, size: image.size)
        text.draw(in: rect, withAttributes: textFontAttributes)
        
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage!
    }
    
    func determineDistanceFromUser(driverLocation: CLLocation) -> String{
        var userCoords = CLLocation(latitude: userLocation.coordinate.latitude, longitude: userLocation.coordinate.longitude)
        let distanceInMeters = userCoords.distance(from: driverLocation)
        let distanceInMiles = distanceInMeters / 1609
        return "\(round(distanceInMiles * 100) / 100) Miles"
    }
    
    
    func sceneLocationViewDidAddSceneLocationEstimate(sceneLocationView: SceneLocationView, position: SCNVector3, location: CLLocation) {
        print("add scene location estimate, position: \(position), location: \(location.coordinate), accuracy: \(location.horizontalAccuracy), date: \(location.timestamp)")
    }
    
    func sceneLocationViewDidRemoveSceneLocationEstimate(sceneLocationView: SceneLocationView, position: SCNVector3, location: CLLocation) {
        print("remove scene location estimate, position: \(position), location: \(location.coordinate), accuracy: \(location.horizontalAccuracy), date: \(location.timestamp)")
    }
    
    func sceneLocationViewDidConfirmLocationOfNode(sceneLocationView: SceneLocationView, node: LocationNode) {
    }
    
    func sceneLocationViewDidSetupSceneNode(sceneLocationView: SceneLocationView, sceneNode: SCNNode) {
        
    }
    
    func sceneLocationViewDidUpdateLocationAndScaleOfLocationNode(sceneLocationView: SceneLocationView, locationNode: LocationNode) {
        
    }
    
    @objc func updateUserLocation() {
        if let currentLocation = sceneLocationView.currentLocation() {
            DispatchQueue.main.async {
                
                if let bestEstimate = self.sceneLocationView.bestLocationEstimate(),
                    let position = self.sceneLocationView.currentScenePosition() {
                    print("Fetch current location")
                    print("best location estimate, position: \(bestEstimate.position), location: \(bestEstimate.location.coordinate), accuracy: \(bestEstimate.location.horizontalAccuracy), date: \(bestEstimate.location.timestamp)")
                    print("current position: \(position)")
                    
                    let translation = bestEstimate.translatedLocation(to: position)
                    
                    print("translation: \(translation)")
                    print("translated location: \(currentLocation)")
                    print("")
                }
                
                if self.userAnnotation == nil {
                    self.userAnnotation = MKPointAnnotation()
                    self.mapView.addAnnotation(self.userAnnotation!)
                }
                
                UIView.animate(withDuration: 0.5, delay: 0, options: UIViewAnimationOptions.allowUserInteraction, animations: {
                    self.userAnnotation?.coordinate = currentLocation.coordinate
                }, completion: nil)
                
                if self.centerMapOnUserLocation {
                    UIView.animate(withDuration: 0.45, delay: 0, options: UIViewAnimationOptions.allowUserInteraction, animations: {
                        self.mapView.setCenter(self.userAnnotation!.coordinate, animated: false)
                    }, completion: {
                        _ in
                        self.mapView.region.span = MKCoordinateSpan(latitudeDelta: 0.0005, longitudeDelta: 0.0005)
                    })
                }
                
                if self.displayDebugging {
                    let bestLocationEstimate = self.sceneLocationView.bestLocationEstimate()
                    
                    if bestLocationEstimate != nil {
                        if self.locationEstimateAnnotation == nil {
                            self.locationEstimateAnnotation = MKPointAnnotation()
                            self.mapView.addAnnotation(self.locationEstimateAnnotation!)
                        }
                        
                        self.locationEstimateAnnotation!.coordinate = bestLocationEstimate!.location.coordinate
                    } else {
                        if self.locationEstimateAnnotation != nil {
                            self.mapView.removeAnnotation(self.locationEstimateAnnotation!)
                            self.locationEstimateAnnotation = nil
                        }
                    }
                }
            }
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.view.endEditing(true)
        return false
    }
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }

    // MARK: - ARSCNViewDelegate
    
/*
    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()
     
        return node
    }
*/
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
}