//
//  GameViewController.swift
//  QuadQuarantine
//
//  Created by Hugo Miguel Ribeiro Oliveira on 15/04/2026.
//

import UIKit
import SpriteKit
import GameplayKit

class GameViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let skView = self.view as? SKView else { return }
        
        // Present the Main Menu as the entry point
        let scene = MainMenuScene(size: skView.bounds.size)
        scene.scaleMode = .resizeFill
        skView.presentScene(scene)
        
        skView.ignoresSiblingOrder = true
        
        // Disable in production — left on for convenience during development
        skView.showsFPS = true
        skView.showsNodeCount = true
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscape
    }

    override var shouldAutorotate: Bool {
        return true
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
