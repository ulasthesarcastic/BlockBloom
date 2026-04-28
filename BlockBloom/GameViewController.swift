//
//  GameViewController.swift
//  BlockBloom
//
//  Created by Ulaş Sancaklı on 26.04.2026.
//

import UIKit
import SpriteKit
import GameplayKit

class GameViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // AdMob başlat
        AdManager.setup()
        AdManager.shared.preload()

        guard let skView = self.view as? SKView else { return }

        let scene = MenuScene()
        scene.scaleMode = .resizeFill
        skView.presentScene(scene)
        skView.ignoresSiblingOrder = true
        skView.showsFPS = false
        skView.showsNodeCount = false
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
