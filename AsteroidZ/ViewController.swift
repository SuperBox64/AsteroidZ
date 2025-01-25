//
//  ViewController.swift
//  AsteroidZ
//
//  Created by SuperBox64m on 12/31/24.
//

import Cocoa
import SpriteKit
import GameplayKit

@objc
class ViewController: NSViewController {

    @IBOutlet var skView: SKView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let view = self.skView {
            let scene = GameScene(size: CGSize(width: 1920, height: 1080))
            scene.scaleMode = .aspectFill
            
            view.ignoresSiblingOrder = true
            view.isAsynchronous = true
            view.showsFPS = false
            view.showsPhysics = false
            view.showsFields = false
            view.shouldCullNonVisibleNodes = true
            view.allowsTransparency = true
            view.preferredFramesPerSecond = 120 //The limit is 60, but this keeps the game playing fast and smooth on 5K displays.
            view.showsNodeCount = false
            view.presentScene(scene)

        }
    }
}

