/*
    ViewController.swift
    Something
 
    This iOS application was created for the New Media Institute during Capstone Fall 2018 by the following members:
 
    Andrew Buhler     - iOS Developer
    Brady Eastin      - Project Manager
    Cam Walker        - Design Lead
    Haley Naylor      - Content Lead
    Madison Ambrogio  - Branding Lead
 
    Our mentor was Chris Gerlach
*/

import ARKit
import CoreLocation
import Firebase
import FirebaseDatabase
import MapKit
import SceneKit
import UIKit
import AVFoundation

class ViewController: UIViewController, ARSCNViewDelegate, CLLocationManagerDelegate, UITextFieldDelegate, UIGestureRecognizerDelegate, UIPickerViewDelegate, UIPickerViewDataSource {
    
    // Anchor node for the other nodes to be added to
    var anchorNode = SCNNode()
    
    // Variables for the color choices
    let colorName = ["Red", "Black", "Green", "Blue", "Yellow", "Orange", "Gray"]
    let colorDictionary = ["Red": UIColor.red, "Black": UIColor.black, "Green": UIColor.green, "Blue": UIColor.blue, "Yellow": UIColor.yellow, "Orange": UIColor.orange, "Gray": UIColor.gray]
    
    // Textfield for the user to enter text
    @IBOutlet weak var input: UITextField!
    
    // Keeps track of the user's latitude and longitude
    var locationManager = CLLocationManager()
    
    // The x coordinate for the side menu
    @IBOutlet weak var menuX: NSLayoutConstraint!
    
    // Value of color dictionary displayed to user
    @IBOutlet weak var colorPicker: UIPickerView!
    
    // The AR session scene view
    @IBOutlet var sceneView: ARSCNView!
    
    // Handles the connection to the database
    var handler:DatabaseHandle?
    
    // The reference of the database
    var reference:DatabaseReference!
    
    // GPS coordinates
    var latitude: Double = 0.0
    var longitude: Double = 0.0
    
    // In app function when the button is pressed to show the website
    @IBAction func showWebsite(_ sender: Any) {
        if let url = NSURL(string: "http://app.mynmi.net") {
            UIApplication.shared.openURL(url as URL)
        } // if
    } // show website
    
    // Controls the side menu and when it is shown
    var menuShowing = false
    @IBAction func shiftMenu(_ sender: Any) {
        if (menuShowing) {
            menuX.constant = -240
        } else {
            menuX.constant = 0
        } // if
        
        UIView.animate(withDuration: 0.3, animations: {
            self.view.layoutIfNeeded()
        })
        
        menuShowing = !menuShowing
    } // shift menu
    
    // Sets up the application
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Makes a reference to the database and sets the data from it in the scene
        reference = Database.database().reference()
        
        // Hides the keyboard when screen is tapped away from keyboard
        hideKeyboardWhenTappedAround()
        
        // Check user's location
        self.locationManager.requestWhenInUseAuthorization()
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            locationManager.startUpdatingLocation()
        } // if
        
        // Set the delegates
        sceneView.delegate = self
        input.delegate = self
        colorPicker.delegate = (self as UIPickerViewDelegate)
        colorPicker.dataSource = self

        
        // Run the session with test info and origin displayed.
        //runTests()
    } // view did load
    
    
    // Handles accessing the data from Firebase upon app startup
    func handleData() {
        reference.child("Test").observeSingleEvent(of: .value, with: { (snapshot) in
            if let result = snapshot.children.allObjects as? [DataSnapshot] {
                for child in result {
                    let xCoord = Float(truncating: child.childSnapshot(forPath: "X").value as! NSNumber)
                    let yCoord = Float(truncating: child.childSnapshot(forPath: "Y").value as! NSNumber)
                    let zCoord = Float(truncating: child.childSnapshot(forPath: "Z").value as! NSNumber)
                    let colorIndex = Float(truncating: child.childSnapshot(forPath: "Color Index").value as! NSNumber)
                    let sizeChoice = Float(truncating: child.childSnapshot(forPath: "Size").value as! NSNumber)
                    
                    let inscription = child.childSnapshot(forPath: "Text").value
                    
                    self.placeNode(x: xCoord , y: yCoord , z: zCoord , text: inscription as! String, size: sizeChoice, color: colorIndex)
                } // for
            } // if
        }) // reference
    } // func
    
    // Next three functions involve the pickerview
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    } // number of components
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return colorName.count
    } // pickerView
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return colorName[row]
    } // pickerview
    
    // Slider for adjusting the text size
    @IBOutlet weak var textSizeSlider: UISlider!
    
    // Label for the color type
    @IBOutlet weak var colorLabel: UILabel!
    
    // Sets text in area
    var touchX : Float = 0.0
    var touchY : Float = 0.0
    var touchZ : Float = 0.0
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        // function has been modified to not place empty strings
        if (input.text == "") {
            print("Textfield is empty!")
            return
        } // if
        
        let textNode = SCNNode()
        var writing = SCNText()
        
        guard let touch = touches.first else { return }
        let result = sceneView.hitTest(touch.location(in: sceneView), types: [ARHitTestResult.ResultType.featurePoint])
        guard let hitResult = result.last else {return}
        let hitTransform = SCNMatrix4.init(hitResult.worldTransform)
        let hitVector = SCNVector3Make(hitTransform.m41, hitTransform.m42, hitTransform.m43)
        
        touchX = hitTransform.m41
        touchY = hitTransform.m42
        touchZ = hitTransform.m43
        
        writing = SCNText(string: input.text, extrusionDepth: 1)
        
        let material = SCNMaterial()
        material.isDoubleSided = true
        material.diffuse.contents = colorDictionary[colorName[colorPicker.selectedRow(inComponent: 0)]]
        
        writing.materials = [material]
        
        textNode.scale = SCNVector3(textSizeSlider.value, textSizeSlider.value, textSizeSlider.value)
        textNode.geometry = writing
        textNode.constraints = [SCNBillboardConstraint()]
        textNode.position = hitVector
        sceneView.scene.rootNode.addChildNode(textNode)
        
        // Add the necessary info to Firebase
        let values = ["X" : touchX, "Y" : touchY, "Z" : touchZ, "Text" : input.text!, "Size" : textSizeSlider.value, "Color Index" : colorPicker.selectedRow(inComponent: 0)] as [String : Any]
        let childKey = reference.child("Test").childByAutoId().key
        let child = reference.child("Test").child(childKey!)
        child.updateChildValues(values)
    } // override func
   
    // Add text from Firebase to the scene
    func placeNode(x: Float, y: Float, z: Float, text: String, size: Float, color: Float) -> Void {
        let textNode = SCNNode()
        var writing = SCNText()
        
        let hitVector = SCNVector3Make(x, y, z)
        
        touchX = x
        touchY = y
        touchZ = z
        
        writing = SCNText(string: text, extrusionDepth: 1)
        
        let material = SCNMaterial()
        material.isDoubleSided = true
        
        material.diffuse.contents = colorDictionary[colorName[Int(color)]]
        writing.materials = [material]
        
        textNode.scale = SCNVector3(size, size, size)
        textNode.geometry = writing
        textNode.constraints = [SCNBillboardConstraint()]
        textNode.position = hitVector
        sceneView.scene.rootNode.addChildNode(textNode)
    } // func
    
    // Gives the longitude and latitude
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let localValue: CLLocationCoordinate2D = manager.location!.coordinate
        latitude = localValue.latitude
        longitude = localValue.longitude
    } // func
    
    // Sets up the configuration for the code scan
    func setupConfig() {
        // get the image to check
        guard let referenceImages = ARReferenceImage.referenceImages(inGroupNamed: "AR Resources", bundle: nil) else {
            fatalError("Missing expected asset catalog resources.")
        } // reference images
        
        // setup the configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.detectionImages = referenceImages
        configuration.maximumNumberOfTrackedImages = 1
        
        // detect planes
        configuration.planeDetection = .horizontal
        configuration.planeDetection = .vertical
        
        // run the configuration in the session
        sceneView.session.run(configuration)
    } // setupConfig
    
    // viewWillAppear and viewWillDisappear are default functions provided by XCode for setting up an AR application
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
         colorPicker.setValue(UIColor.white, forKeyPath: "textColor")
        setupConfig()
    } // view will appear
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    } // view will disappear
    
    // Activates the AR session with test info
    func runTests() {
        sceneView.showsStatistics = true
        self.sceneView.debugOptions  = [.showConstraints, .showLightExtents, ARSCNDebugOptions.showFeaturePoints, ARSCNDebugOptions.showWorldOrigin]
    } // func
    
    // session, sessionWasInterrupted, and sessionInterruptionEnded are default functions provided by XCode
    func session(_ session: ARSession, didFailWithError error: Error) {
        print("The session has crashed! D:")
    } // session
    
    func sessionWasInterrupted(_ session: ARSession) {
        print("The session was interrupted! D:")
    } // session was interrupted
    
    func sessionInterruptionEnded(_ session: ARSession) {
        print("The session has ended! D:")
    } // session interrupted
    
    // Checks if enter is pressed
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        print("return pressed")
        input.resignFirstResponder()
        return false
    } // textfield should return
    
    // Manages the image visual scan
    var imageHighlightAction: SCNAction {
        return .sequence([
            .wait(duration: 0.25),
            .fadeOpacity(to: 0.85, duration: 0.25),
            .fadeOpacity(to: 0.15, duration: 0.25),
            .fadeOpacity(to: 0.85, duration: 0.25),
            .fadeOut(duration: 0.5),
            .removeFromParentNode()
            ])
    } // image highlight
    
    // Places the anchor at the image
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        // reveal textfield when image is scanned
        DispatchQueue.main.async {
            UIView.animate(withDuration: 0.6, animations: {
                var frame = self.input.frame
                frame.origin.y = 20
                self.input.frame = frame
                self.input.layoutIfNeeded()
            })
        } // dispatch
        
        guard let imageAnchor = anchor as? ARImageAnchor else { return }
        let referenceImage = imageAnchor.referenceImage
        
        sceneView.session.setWorldOrigin(relativeTransform: imageAnchor.transform)
        
        let nodeGeometry = SCNText(string: "Welcome!", extrusionDepth: 1)
        nodeGeometry.font = UIFont(name: "Helvetica", size: 30)
        nodeGeometry.firstMaterial?.diffuse.contents = UIColor.black
        
        anchorNode.geometry = nodeGeometry
        anchorNode.scale = SCNVector3(0.1, 0.1, 0.1)
        anchorNode.constraints = [SCNBillboardConstraint()]
        anchorNode.position = SCNVector3(imageAnchor.transform.columns.3.x, imageAnchor.transform.columns.3.y, imageAnchor.transform.columns.3.z)
        
        // Create a plane to visualize the initial position of the detected image.
        let plane = SCNPlane(width: referenceImage.physicalSize.width, height: referenceImage.physicalSize.height)
        let planeNode = SCNNode(geometry: plane)
        planeNode.opacity = 0.25
        
        // Plane is rotated to match the picture location
        planeNode.eulerAngles.x = -.pi / 2
        
        // Scan runs as an action for a set amount of time
        planeNode.runAction(self.imageHighlightAction)
        
        // Add the plane visualization to the scene.
        node.addChildNode(planeNode)
        
        //Add the node to the scene
        sceneView.scene.rootNode.addChildNode(node)
        
        //Load the data
        handleData()
    } // renderer
} // class

// Manages the keyboard closing upon touching the screen
extension UIViewController {
    func hideKeyboardWhenTappedAround() {
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(UIViewController.dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    } // hide keyboard
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    } // dismiss keyboard
} // extension
