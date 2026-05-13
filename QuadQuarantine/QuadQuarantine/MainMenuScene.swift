//
//  MainMenuScene.swift
//  QuadQuarantine
//

import SpriteKit

class MainMenuScene: SKScene {

    // MARK: - Persistence Keys (must match GameScene)
    private enum PersistenceKey {
        static let bestSurvivalTime   = "bestSurvivalTime"
        static let totalDataBitsBank  = "totalDataBitsBank"
        static let highestLevelReached = "highestLevelReached"
    }

    // MARK: - Lifecycle
    override func didMove(to view: SKView) {
        self.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        self.backgroundColor = SKColor(red: 0.04, green: 0.06, blue: 0.10, alpha: 1.0)

        addGridBackground()
        addScanlineEffect()
        addTitle()
        addStatsPanel()
        addPlayButton()
        addStatsButton()
        addVersionLabel()
        animateScene()
    }

    // MARK: - Background

    /// Draws a subtle dot-grid to reinforce the "digital arena" feel.
    private func addGridBackground() {
        let gridNode = SKNode()
        gridNode.zPosition = -10

        let cols = Int(size.width  / 40) + 2
        let rows = Int(size.height / 40) + 2
        let startX = -size.width  / 2
        let startY = -size.height / 2

        for col in 0..<cols {
            for row in 0..<rows {
                let dot = SKShapeNode(circleOfRadius: 1.2)
                dot.fillColor = SKColor(white: 1.0, alpha: 0.08)
                dot.strokeColor = .clear
                dot.position = CGPoint(
                    x: startX + CGFloat(col) * 40,
                    y: startY + CGFloat(row) * 40
                )
                gridNode.addChild(dot)
            }
        }
        addChild(gridNode)

        // Corner accent lines — top-left
        let corner = SKShapeNode()
        let path = CGMutablePath()
        let cx = -size.width / 2 + 28
        let cy =  size.height / 2 - 28
        path.move(to: CGPoint(x: cx, y: cy - 36))
        path.addLine(to: CGPoint(x: cx, y: cy))
        path.addLine(to: CGPoint(x: cx + 36, y: cy))
        corner.path = path
        corner.strokeColor = SKColor(red: 0.0, green: 0.9, blue: 0.7, alpha: 0.55)
        corner.lineWidth = 2
        corner.zPosition = 1
        addChild(corner)

        // Bottom-right mirror
        let corner2 = SKShapeNode()
        let path2 = CGMutablePath()
        let cx2 =  size.width  / 2 - 28
        let cy2 = -size.height / 2 + 28
        path2.move(to: CGPoint(x: cx2, y: cy2 + 36))
        path2.addLine(to: CGPoint(x: cx2, y: cy2))
        path2.addLine(to: CGPoint(x: cx2 - 36, y: cy2))
        corner2.path = path2
        corner2.strokeColor = SKColor(red: 0.0, green: 0.9, blue: 0.7, alpha: 0.55)
        corner2.lineWidth = 2
        corner2.zPosition = 1
        addChild(corner2)
    }

    /// Animating horizontal scanline for atmosphere.
    private func addScanlineEffect() {
        let line = SKShapeNode(rectOf: CGSize(width: size.width, height: 2))
        line.fillColor = SKColor(white: 1.0, alpha: 0.03)
        line.strokeColor = .clear
        line.position = CGPoint(x: 0, y: -size.height / 2)
        line.zPosition = 0
        line.name = "scanline"
        addChild(line)

        let move = SKAction.moveTo(y: size.height / 2, duration: 4.5)
        let reset = SKAction.moveTo(y: -size.height / 2, duration: 0)
        line.run(SKAction.repeatForever(SKAction.sequence([move, reset])))
    }

    // MARK: - Title

    private func addTitle() {
        // Glow behind the title
        let glow = SKShapeNode(ellipseOf: CGSize(width: 520, height: 90))
        glow.fillColor = SKColor(red: 0.0, green: 0.85, blue: 0.65, alpha: 0.07)
        glow.strokeColor = .clear
        glow.position = CGPoint(x: 0, y: size.height * 0.30)
        glow.zPosition = 2
        glow.name = "titleGlow"
        addChild(glow)

        // Main title
        let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        title.text = "QUAD"
        title.fontSize = 72
        title.fontColor = .white
        title.horizontalAlignmentMode = .center
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: -255, y: size.height * 0.30)
        title.zPosition = 10
        title.name = "titleLabel"
        addChild(title)

        let title2 = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        title2.text = "QUARANTINE"
        title2.fontSize = 72
        title2.fontColor = SKColor(red: 0.0, green: 0.95, blue: 0.75, alpha: 1.0)
        title2.horizontalAlignmentMode = .center
        title2.verticalAlignmentMode = .center
        title2.position = CGPoint(x: 162, y: size.height * 0.30)
        title2.zPosition = 10
        title2.name = "titleLabel2"
        addChild(title2)

        // Thin horizontal rule below title
        let rule = SKShapeNode(rectOf: CGSize(width: 460, height: 1.5))
        rule.fillColor = SKColor(red: 0.0, green: 0.95, blue: 0.75, alpha: 0.45)
        rule.strokeColor = .clear
        rule.position = CGPoint(x: 0, y: size.height * 0.30 - 46)
        rule.zPosition = 10
        addChild(rule)

        // Subtitle / tagline
        let sub = SKLabelNode()
        sub.attributedText = NSAttributedString(
            string: "SURVIVE. EVOLVE. ESCAPE.",
            attributes: [
                .font: UIFont(name: "AvenirNext-Medium", size: 15)!,
                .foregroundColor: UIColor(white: 0.55, alpha: 1.0),
                .kern: 3.5
            ]
        )
        sub.horizontalAlignmentMode = .center
        sub.position = CGPoint(x: 0, y: size.height * 0.30 - 66)
        sub.zPosition = 10
        addChild(sub)
    }

    // MARK: - Stats Panel

    private func addStatsPanel() {
        let defaults = UserDefaults.standard
        let bestTime        = defaults.double(forKey: PersistenceKey.bestSurvivalTime)
        let dataBits        = defaults.integer(forKey: PersistenceKey.totalDataBitsBank)
        let highestLevel    = max(1, defaults.integer(forKey: PersistenceKey.highestLevelReached))

        let panelW: CGFloat = 380
        let panelH: CGFloat = 96
        let panelY: CGFloat = size.height * 0.00

        let panel = SKShapeNode(rectOf: CGSize(width: panelW, height: panelH), cornerRadius: 12)
        panel.fillColor = SKColor(white: 0.08, alpha: 0.85)
        panel.strokeColor = SKColor(white: 0.22, alpha: 1.0)
        panel.lineWidth = 1.5
        panel.position = CGPoint(x: 0, y: panelY)
        panel.zPosition = 5
        addChild(panel)

        // Three stat columns
        let stats: [(icon: String, value: String, label: String, xOffset: CGFloat)] = [
            ("⏱", formattedTime(bestTime), "BEST TIME",    -128),
            ("⬡",  "\(dataBits)",          "DATA BITS",       0),
            ("⬆", "LVL \(highestLevel)",   "HIGHEST",       128),
        ]

        for stat in stats {
            // Icon
            let icon = SKLabelNode(fontNamed: "AvenirNext-Bold")
            icon.text = stat.icon
            icon.fontSize = 20
            icon.fontColor = SKColor(red: 0.0, green: 0.95, blue: 0.75, alpha: 0.85)
            icon.horizontalAlignmentMode = .center
            icon.verticalAlignmentMode = .center
            icon.position = CGPoint(x: stat.xOffset, y: panelY + 26)
            icon.zPosition = 6
            addChild(icon)

            // Value
            let val = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
            val.text = stat.value
            val.fontSize = 18
            val.fontColor = .white
            val.horizontalAlignmentMode = .center
            val.verticalAlignmentMode = .center
            val.position = CGPoint(x: stat.xOffset, y: panelY + 4)
            val.zPosition = 6
            addChild(val)

            // Label
            let lbl = SKLabelNode()
            lbl.attributedText = NSAttributedString(
                string: stat.label,
                attributes: [
                    .font: UIFont(name: "AvenirNext-Regular", size: 11)!,
                    .foregroundColor: UIColor(white: 0.45, alpha: 1.0),
                    .kern: 2.0
                ]
            )
            lbl.horizontalAlignmentMode = .center
            lbl.verticalAlignmentMode = .center
            lbl.position = CGPoint(x: stat.xOffset, y: panelY - 20)
            lbl.zPosition = 6
            addChild(lbl)
        }

        // Vertical dividers
        for xDiv in [-64.0, 64.0] as [CGFloat] {
            let div = SKShapeNode(rectOf: CGSize(width: 1, height: panelH - 28))
            div.fillColor = SKColor(white: 0.22, alpha: 1.0)
            div.strokeColor = .clear
            div.position = CGPoint(x: xDiv, y: panelY)
            div.zPosition = 6
            addChild(div)
        }
    }

    // MARK: - Play Button

    private func addPlayButton() {
        let btnY: CGFloat = -size.height * 0.24

        // Outer glow ring
        let ring = SKShapeNode(rectOf: CGSize(width: 218, height: 64), cornerRadius: 32)
        ring.fillColor = .clear
        ring.strokeColor = SKColor(red: 0.0, green: 0.95, blue: 0.75, alpha: 0.25)
        ring.lineWidth = 6
        ring.position = CGPoint(x: 0, y: btnY)
        ring.zPosition = 8
        ring.name = "playRing"
        addChild(ring)

        // Button body
        let btn = SKShapeNode(rectOf: CGSize(width: 206, height: 52), cornerRadius: 26)
        btn.fillColor = SKColor(red: 0.0, green: 0.85, blue: 0.65, alpha: 1.0)
        btn.strokeColor = .clear
        btn.position = CGPoint(x: 0, y: btnY)
        btn.zPosition = 9
        btn.name = "playButton"
        addChild(btn)

        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = "PLAY"
        label.fontSize = 26
        label.fontColor = SKColor(red: 0.03, green: 0.06, blue: 0.10, alpha: 1.0)
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: btnY)
        label.zPosition = 10
        label.isUserInteractionEnabled = false
        addChild(label)

        // Pulse animation on the glow ring
        let scaleUp   = SKAction.scale(to: 1.08, duration: 0.9)
        let scaleDown = SKAction.scale(to: 1.00, duration: 0.9)
        scaleUp.timingMode   = .easeInEaseOut
        scaleDown.timingMode = .easeInEaseOut
        let fadeUp   = SKAction.fadeAlpha(to: 0.55, duration: 0.9)
        let fadeDown = SKAction.fadeAlpha(to: 0.25, duration: 0.9)
        ring.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.group([scaleUp, fadeUp]),
            SKAction.group([scaleDown, fadeDown])
        ])))
    }

    // MARK: - Stats Button

    private func addStatsButton() {
        let btn = SKShapeNode(rectOf: CGSize(width: 140, height: 38), cornerRadius: 10)
        btn.fillColor = SKColor(white: 0.08, alpha: 0.9)
        btn.strokeColor = SKColor(white: 0.22, alpha: 1.0)
        btn.lineWidth = 1.5
        btn.position = CGPoint(x: 0, y: -size.height * 0.38)
        btn.zPosition = 5
        btn.name = "statsButton"
        addChild(btn)

        let lbl = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        lbl.text = "PLAYER STATS"
        lbl.fontSize = 13
        lbl.fontColor = SKColor(red: 0.0, green: 0.95, blue: 0.75, alpha: 0.85)
        lbl.horizontalAlignmentMode = .center
        lbl.verticalAlignmentMode = .center
        lbl.position = CGPoint.zero
        lbl.isUserInteractionEnabled = false
        btn.addChild(lbl)
    }

    // MARK: - Version Label

    private func addVersionLabel() {
        let ver = SKLabelNode(fontNamed: "AvenirNext-Regular")
        ver.text = "v0.1"
        ver.fontSize = 11
        ver.fontColor = SKColor(white: 0.28, alpha: 1.0)
        ver.horizontalAlignmentMode = .right
        ver.position = CGPoint(x: size.width / 2 - 16, y: -size.height / 2 + 12)
        ver.zPosition = 5
        addChild(ver)
    }

    // MARK: - Entry Animation

    private func animateScene() {
        // Fade-in entire scene
        self.alpha = 0
        run(SKAction.fadeIn(withDuration: 0.65))

        // Title subtle float
        guard let t1 = childNode(withName: "titleLabel"),
              let t2 = childNode(withName: "titleLabel2") else { return }
        let floatUp   = SKAction.moveBy(x: 0, y: 5, duration: 2.2)
        let floatDown = SKAction.moveBy(x: 0, y: -5, duration: 2.2)
        floatUp.timingMode   = .easeInEaseOut
        floatDown.timingMode = .easeInEaseOut
        let floatLoop = SKAction.repeatForever(SKAction.sequence([floatUp, floatDown]))
        t1.run(floatLoop)
        t2.run(floatLoop)

        // Glow breathe
        guard let glow = childNode(withName: "titleGlow") else { return }
        let glowIn  = SKAction.fadeAlpha(to: 0.14, duration: 1.8)
        let glowOut = SKAction.fadeAlpha(to: 0.05, duration: 1.8)
        glow.run(SKAction.repeatForever(SKAction.sequence([glowIn, glowOut])))
    }

    // MARK: - Input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let tapped = nodes(at: location)

        let hitPlay  = tapped.contains(where: { $0.name == "playButton" || $0.name == "playRing" })
        let hitStats = tapped.contains(where: { $0.name == "statsButton" })

        if hitStats {
            let scene = PlayerStatsScene(size: size)
            scene.scaleMode = scaleMode
            view?.presentScene(scene, transition: SKTransition.fade(
                with: SKColor(red: 0.04, green: 0.06, blue: 0.10, alpha: 1.0),
                duration: 0.35
            ))
            return
        }

        guard hitPlay else { return }

        // Brief scale-down feedback, then transition
        if let btn = childNode(withName: "playButton") {
            let press   = SKAction.scale(to: 0.93, duration: 0.07)
            let release = SKAction.scale(to: 1.00, duration: 0.07)
            btn.run(SKAction.sequence([press, release])) { [weak self] in
                self?.transitionToGame()
            }
        } else {
            transitionToGame()
        }
    }

    // MARK: - Transition

    private func transitionToGame() {
        let scene: GameScene
        if let loaded = GameScene(fileNamed: "GameScene") {
            scene = loaded
        } else {
            scene = GameScene(size: size)
        }
        scene.scaleMode = scaleMode

        let transition = SKTransition.fade(with: SKColor(red: 0.04, green: 0.06, blue: 0.10, alpha: 1.0),
                                           duration: 0.4)
        view?.presentScene(scene, transition: transition)
    }

    // MARK: - Helpers

    private func formattedTime(_ time: TimeInterval) -> String {
        let total   = Int(max(0, time.rounded(.down)))
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
