//
//  ViewController.swift
//  MagicHat
//
//  Created by Evandro Harrison Hoffmann on 12/7/17.
//  Copyright © 2017 Evandro Harrison Hoffmann. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController {

    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var magicButton: UIButton!
    @IBOutlet weak var throwBallButton: UIButton!
    
    fileprivate var hatNode: SCNNode?
    fileprivate var planeNode: SCNNode?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self
        sceneView.showsStatistics = true
        sceneView.scene = SCNScene()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    // MARK: - Events
    
    @IBAction func magicButtonPressed(_ sender: Any) {
    }
    
    @IBAction func throwBallButtonPressed(_ sender: Any) {
        shootBall()
    }
    
    @IBAction func didTap(_ sender: UITapGestureRecognizer) {
        guard hatNode == nil else {
            return
        }
        
        let location = sender.location(in: sceneView)
        let results = sceneView.hitTest(location, types: .existingPlaneUsingExtent)
        if let result = results.first {
            placeHat(result)
        }
    }
}

// MARK: - Hat Configuration

extension ViewController {
    
    private func placeHat(_ result: ARHitTestResult) {
        
        // Get transform of result
        let transform = result.worldTransform
        
        // Get position from transform (4th column of transformation matrix)
        let planePosition = SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
        
        // can only add one hat
        hatNode?.removeFromParentNode()
        hatNode = createHatFromScene(planePosition)
        if let hatNode = hatNode {
            sceneView.scene.rootNode.addChildNode(hatNode)
        }
    }
    
    private func createHatFromScene(_ position: SCNVector3) -> SCNNode? {
        guard let url = Bundle.main.url(forResource: "art.scnassets/hat", withExtension: "scn") else {
            NSLog("Could not find hat scene")
            return nil
        }
        guard let node = SCNReferenceNode(url: url) else { return nil }
        
        node.load()
        
        // Position scene
        node.position = position
        
        return node
    }
}

// MARK: - Ball Configuration

extension ViewController {
    
    fileprivate func shootBall() {
        guard let ballNode = createBallFromScene() else {
            return
        }
        
        let camera = self.sceneView.pointOfView!
        let position = SCNVector3(x: 0, y: 0, z: -0.20)
        ballNode.position = camera.convertPosition(position, to: nil)
        ballNode.rotation = camera.rotation
        
        let direction = getCameraDirection()
        let ballDirection = direction
        ballNode.physicsBody?.applyForce(ballDirection, asImpulse: true)
        
        sceneView.scene.rootNode.addChildNode(ballNode)
    }
    
    private func createBallFromScene() -> SCNNode? {
        guard let url = Bundle.main.url(forResource: "art.scnassets/ball", withExtension: "scn") else {
            NSLog("Could not find ball scene")
            return nil
        }
        guard let node = SCNReferenceNode(url: url) else { return nil }

        node.load()

        return node.childNode(withName: "sphere", recursively: true)
    }
}

// MARK: - ARSCNViewDelegate

extension ViewController: ARSCNViewDelegate {
    
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        // Create an SCNNode for a detect ARPlaneAnchor
        guard let _ = anchor as? ARPlaneAnchor else {
            return nil
        }
        planeNode = SCNNode()
        return planeNode
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        // Create an SNCPlane on the ARPlane
        guard let planeAnchor = anchor as? ARPlaneAnchor else {
            return
        }
        
        let plane = SCNPlane(width: CGFloat(planeAnchor.extent.x), height: CGFloat(planeAnchor.extent.z))
        
        let planeMaterial = SCNMaterial()
        planeMaterial.diffuse.contents = UIColor(red: 255/255, green: 255/255, blue: 255/255, alpha: 0.3)
        plane.materials = [planeMaterial]
        
        let planeNode = SCNNode(geometry: plane)
        planeNode.position = SCNVector3Make(planeAnchor.center.x, 0, planeAnchor.center.z)
        
        planeNode.transform = SCNMatrix4MakeRotation(-Float.pi / 2, 1, 0, 0)
        
        node.addChildNode(planeNode)
    }
    
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

// MARK: - User direction

extension ViewController {
    
    func getCameraDirection() -> SCNVector3 {
        if let frame = self.sceneView.session.currentFrame {
            let mat = SCNMatrix4(frame.camera.transform)
            let dir = SCNVector3(-2 * mat.m31, -2 * mat.m32, -2 * mat.m33)
            return dir
        }
        return SCNVector3(0, 0, -1)
    }
}
