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

class SceneViewController: UIViewController {

    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var magicButton: UIButton!
    @IBOutlet weak var throwBallButton: UIButton!
    @IBOutlet weak var instructionsLabel: UILabel!
    
    fileprivate var hatNode: SCNNode?
    fileprivate var groundNode: SCNNode?
    fileprivate var magicEffectSound: SCNAudioSource!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureScene()
        loadSounds()
        updateUI()
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
    
    fileprivate func configureScene() {
        sceneView.delegate = self
        sceneView.showsStatistics = true
        //sceneView.debugOptions = [.showPhysicsShapes]
        sceneView.scene = SCNScene()
        sceneView.scene.physicsWorld.contactDelegate = self
    }
    
    // MARK: - Events
    
    @IBAction func magicButtonPressed(_ sender: Any) {
        clearHat()
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
            let transform = result.worldTransform
            let position = SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
            
            placeHat(planePosition: position,
                     transform: transform)
            
            addFloor(withResult: result)
        }
        
        updateUI()
    }
    
    fileprivate func updateMagicButton() {
        self.magicButton.isEnabled = hatNode != nil
        self.magicButton.alpha = hatNode != nil ? 1 : 0.5
    }
    
    fileprivate func updateThrowBallButton() {
        self.throwBallButton.isEnabled = hatNode != nil
        self.throwBallButton.alpha = hatNode != nil ? 1 : 0.5
    }
    
    fileprivate func updateInstructions() {
        if hatNode != nil {
            instructionsLabel.text = ""
        } else {
            instructionsLabel.text = "Place camera next to ground, facing forward to find a plane for your hat 🎩"
        }
        
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.3, options: .autoreverse, animations: {
            self.instructionsLabel.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        }, completion: nil)
    }
    
    fileprivate func updateUI() {
        updateMagicButton()
        updateThrowBallButton()
        updateInstructions()
    }
}

// MARK: - Hat Configuration

extension SceneViewController {
    
    private func placeHat(planePosition: SCNVector3, transform: matrix_float4x4) {
        // can only add one hat
        hatNode?.removeFromParentNode()
        hatNode = createHatFromScene(planePosition)
        hatNode?.name = NodeNames.hat.rawValue
        if let hatNode = hatNode {
            sceneView.scene.rootNode.addChildNode(hatNode)
            removePlaneIndicator()
        }
    }
    
    private func createHatFromScene(_ position: SCNVector3) -> SCNNode? {
        guard let url = Bundle.main.url(forResource: "art.scnassets/hat", withExtension: "scn") else {
            NSLog("Could not find hat scene")
            return nil
        }
        guard let node = SCNReferenceNode(url: url) else { return nil }
        
        node.load()
        node.position = position
        
        return node
    }
    
    private func createMagicEffectOnHat() {
        guard let hatNode = sceneView.scene.rootNode.childNode(withName: "hat", recursively: true) else { return }
        let sparkles = SCNParticleSystem(named: "magicEffect", inDirectory: nil)!
        hatNode.addParticleSystem(sparkles)
    }
    
    fileprivate func clearHat() {
        createMagicEffectOnHat()
        
        sceneView.scene.rootNode.enumerateChildNodes { (node, _) in
            if !node.isFloor, isBallInsideHat(node) {
                node.removeFromParentNode()
            }
        }
    }
    
    fileprivate var hatHasBallsInside: Bool {
        for node in sceneView.scene.rootNode.childNodes where isBallInsideHat(node) {
            return true
        }
        
        return false
    }
    
    private func isBallInsideHat(_ node: SCNNode) -> Bool {
        
        guard !node.isHat else {
            return false
        }
        
        guard let hat = sceneView.scene.rootNode.childNode(withName: "hat", recursively: true) else {
            return false
        }
        
        let min = hat.convertPosition((hat.boundingBox.min), to: sceneView.scene.rootNode)
        let max = hat.convertPosition((hat.boundingBox.max), to: sceneView.scene.rootNode)
        
        if node.presentation.position.x < 0.99*(max.x) && node.presentation.position.x > 0.99*(min.x) && node.presentation.position.y < 0.99*(max.y) && node.presentation.position.y > 0.99*(min.y) && node.presentation.position.z < 0.99*(max.z) && node.presentation.position.z > 0.99*(min.z) {
            return true
        }
        
        return false
    }
}

// MARK: - Ball Configuration

extension SceneViewController {
    
    fileprivate func shootBall() {
        guard let ballNode = createBallFromScene() else {
            return
        }
        
        let camera = self.sceneView.pointOfView!
        let position = SCNVector3(x: 0, y: 0, z: -0.20)
        ballNode.position = camera.convertPosition(position, to: nil)
        ballNode.rotation = camera.rotation
        
        let ballDirection = cameraDirection
        ballNode.physicsBody?.applyForce(ballDirection, asImpulse: true)
        
        ballNode.name = NodeNames.ball.rawValue
        
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

// MARK: - Floor Configuration

extension SceneViewController {
    
    func addFloor(withResult result: ARHitTestResult) {
        let transform = result.worldTransform
        let planePosition = SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
        let floorNode = createFloorForScene(inPosition: planePosition)!
        floorNode.name = NodeNames.floor.rawValue
        sceneView.scene.rootNode.addChildNode(floorNode)
    }
    
    private func createFloorForScene(inPosition position: SCNVector3) -> SCNNode? {
        let floorNode = SCNNode()
        let floor = SCNFloor()
        floorNode.geometry = floor
        floorNode.geometry?.firstMaterial?.diffuse.contents = UIColor.clear
        floorNode.physicsBody = SCNPhysicsBody(type: .static, shape: nil)
        floorNode.position = position
        
        return floorNode
    }
    
    fileprivate func removePlaneIndicator() {
        sceneView.scene.rootNode.enumerateChildNodes { (node, _) in
            if !node.isFloor, !node.isHat {
                node.removeFromParentNode()
            }
        }
    }
    
}

// MARK: - Sound configuration

extension SceneViewController {
    
    fileprivate func loadSounds() {
        magicEffectSound = SCNAudioSource(fileNamed: "magicEffect.mp3")
        magicEffectSound.load()
    }
    
    private func playMagicEffectSound(toNode node: SCNNode?) {
        guard let node = node else {
            return
        }
        
        let action = SCNAction.playAudio(magicEffectSound, waitForCompletion: false)
        node.runAction(action)
    }
}

// MARK: - ARSCNViewDelegate

extension SceneViewController: ARSCNViewDelegate {
    
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        // Create an SCNNode for a detect ARPlaneAnchor
        guard let _ = anchor as? ARPlaneAnchor else {
            return nil
        }
        groundNode = SCNNode()
        return groundNode
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

extension SceneViewController: SCNPhysicsContactDelegate {
    
    func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
        
        if let identifiedNodes = ballNode(withContact: contact) {
            let velocity = identifiedNodes.0.physicsBody?.velocity.y ?? 0
            print("Collision with ball and \(identifiedNodes.1.name ?? "") with y velocity \(velocity)")
            
            // velocity is less than one, it's stopping
            if velocity < 1 {
                //remove name so that we don't have the same ball hitting over and over again
                identifiedNodes.0.name = nil
                
                if identifiedNodes.1.isHat {
                    playMagicEffectSound(toNode: hatNode)
                }
            }
        }
        
    }
    
    fileprivate func ballNode(withContact contact: SCNPhysicsContact) -> (SCNNode, SCNNode)? {
        if contact.nodeA.isBall {
            return (contact.nodeA, contact.nodeB)
        }
        
        if contact.nodeB.isBall {
            return (contact.nodeB, contact.nodeA)
        }
        
        return nil
    }
    
}

// MARK: - User direction

extension SceneViewController {
    
    var cameraDirection: SCNVector3 {
        if let frame = self.sceneView.session.currentFrame {
            let mat = SCNMatrix4(frame.camera.transform)
            let dir = SCNVector3(-2 * mat.m31, -2 * mat.m32, -2 * mat.m33)
            return dir
        }
        return SCNVector3(0, 0, -1)
    }
}

// MARK: - SCNNode extension

extension SCNNode {
    
    var isBall: Bool {
        return self.name == NodeNames.ball.rawValue
    }
    
    var isHat: Bool {
        return self.name == NodeNames.body.rawValue || self.name == NodeNames.base.rawValue || self.name == NodeNames.top.rawValue || self.name == NodeNames.hat.rawValue
    }
    
    var isFloor: Bool {
        return self.name == NodeNames.floor.rawValue
    }
}

enum NodeNames: String {
    case ball
    case body
    case base
    case top
    case hat
    case floor
}
