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
    
    fileprivate var hatNode: SCNNode?
    fileprivate var planeNode: SCNNode?
    fileprivate var ballsInTheHat: [SCNNode] = []
    fileprivate var magicEffectSound: SCNAudioSource!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureScene()
        loadSounds()
        updateMagicButton()
        updateThrowBallButton()
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
        sceneView.scene = SCNScene()
    }
    
    // MARK: - Events
    
    @IBAction func magicButtonPressed(_ sender: Any) {
        clearHat()
    }
    
    @IBAction func throwBallButtonPressed(_ sender: Any) {
        shootBall()
        updateMagicButton()
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
        
        updateThrowBallButton()
    }
    
    fileprivate func updateMagicButton() {
        self.magicButton.isEnabled = ballsInTheHat.count > 0
        self.magicButton.alpha = ballsInTheHat.count > 0 ? 1 : 0.5
    }
    
    fileprivate func updateThrowBallButton() {
        self.throwBallButton.isEnabled = hatNode != nil
        self.throwBallButton.alpha = hatNode != nil ? 1 : 0.5
    }
}

// MARK: - Hat Configuration

extension SceneViewController {
    
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
        node.position = position
        
        return node
    }
    
    private func createMagicEffectOnHat() {
        guard let url = Bundle.main.url(forResource: "art.scnassets/magicEffect", withExtension: "scn") else {
            NSLog("Could not find magic effect scene")
            return
        }
        guard let node = SCNReferenceNode(url: url) else { return }
        
        node.load()
        
        if let hatNode = hatNode {
            node.position = hatNode.position
        }
        
        sceneView.scene.rootNode.addChildNode(node)
    }
    
    fileprivate func clearHat() {
        createMagicEffectOnHat()
        
        for ball in ballsInTheHat {
            ball.removeFromParentNode()
        }
        
        updateMagicButton()
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
        
        let direction = getCameraDirection()
        let ballDirection = direction
        ballNode.physicsBody?.applyForce(ballDirection, asImpulse: true)
        
        sceneView.scene.rootNode.addChildNode(ballNode)
        
        ballsInTheHat.append(ballNode)
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

// MARK: - Sound configuration

extension SceneViewController {
    
    fileprivate func loadSounds() {
        magicEffectSound = SCNAudioSource(fileNamed: "art.scnassets/magicEffect.mp3")
        magicEffectSound.load()
    }
    
    private func playMagicEffectSound(toNode node: SCNNode) {
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

extension SceneViewController: SKPhysicsContactDelegate {
    
    func didBegin(_ contact: SKPhysicsContact) {
//        CollisionCategory contactMask =
//            contact.nodeA.physicsBody.categoryBitMask | contact.nodeB.physicsBody.categoryBitMask;
//
//        // first, sort out what kind of collision
//        if (contactMask == (CollisionCategoryMissile | CollisionCategoryRocket)) {
//            // next, sort out which body is the missile and which is the rocket
//            // and do something about it
//            if (contact.nodeA.physicsBody.categoryBitMask == CollisionCategoryMissile) {
//                [self hitRocket:contact.nodeB withMissile:contact.nodeA];
//            } else {
//                [self hitRocket:contact.nodeA withMissile:contact.nodeB];
//            }
//        } else if (contactMask == (CollisionCategoryMissile | CollisionCategoryAsteroid)) {
//            // ... and so on ...
//        }
    }
    
    
}

// MARK: - User direction

extension SceneViewController {
    
    func getCameraDirection() -> SCNVector3 {
        if let frame = self.sceneView.session.currentFrame {
            let mat = SCNMatrix4(frame.camera.transform)
            let dir = SCNVector3(-2 * mat.m31, -2 * mat.m32, -2 * mat.m33)
            return dir
        }
        return SCNVector3(0, 0, -1)
    }
}
