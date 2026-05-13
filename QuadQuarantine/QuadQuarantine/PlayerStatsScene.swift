//
//  PlayerStatsScene.swift
//  QuadQuarantine
//

import SpriteKit

class PlayerStatsScene: SKScene {

    // MARK: - Persistence Keys (must match GameScene)
    private enum PersistenceKey {
        static let bestSurvivalTime    = "bestSurvivalTime"
        static let totalDataBitsBank   = "totalDataBitsBank"
        static let highestLevelReached = "highestLevelReached"
    }

    // MARK: - Lifecycle
    override func didMove(to view: SKView) {
        self.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        self.backgroundColor = SKColor(red: 0.04, green: 0.06, blue: 0.10, alpha: 1.0)

        addGridBackground()
        addTitle()
        addStatsCards()
        addResetButton()
        addBackButton()
        fadeIn()
    }

    // MARK: - Background
    private func addGridBackground() {
        let cols = Int(size.width  / 40) + 2
        let rows = Int(size.height / 40) + 2
        let startX = -size.width  / 2
        let startY = -size.height / 2

        for col in 0..<cols {
            for row in 0..<rows {
                let dot = SKShapeNode(circleOfRadius: 1.2)
                dot.fillColor = SKColor(white: 1.0, alpha: 0.06)
                dot.strokeColor = .clear
                dot.position = CGPoint(x: startX + CGFloat(col) * 40,
                                       y: startY + CGFloat(row) * 40)
                dot.zPosition = -10
                addChild(dot)
            }
        }

        // Corner accents
        func makeCorner(x: CGFloat, y: CGFloat, dx: CGFloat, dy: CGFloat) {
            let shape = SKShapeNode()
            let path  = CGMutablePath()
            path.move(to: CGPoint(x: x, y: y + dy))
            path.addLine(to: CGPoint(x: x, y: y))
            path.addLine(to: CGPoint(x: x + dx, y: y))
            shape.path = path
            shape.strokeColor = SKColor(red: 0.0, green: 0.9, blue: 0.7, alpha: 0.55)
            shape.lineWidth = 2
            shape.zPosition = 1
            addChild(shape)
        }
        let cx = size.width  / 2 - 28
        let cy = size.height / 2 - 28
        makeCorner(x: -cx, y:  cy - 40, dx:  36, dy: -36)
        makeCorner(x:  cx, y: -cy, dx: -36, dy:  36)
    }

    // MARK: - Title
    private func addTitle() {
        let back = SKShapeNode(rectOf: CGSize(width: size.width, height: 56))
        back.fillColor = SKColor(white: 0.0, alpha: 0.30)
        back.strokeColor = .clear
        back.position = CGPoint(x: 0, y: size.height / 2 - 28)
        back.zPosition = 2
        addChild(back)

        let rule = SKShapeNode(rectOf: CGSize(width: size.width, height: 1.5))
        rule.fillColor = SKColor(red: 0.0, green: 0.95, blue: 0.75, alpha: 0.4)
        rule.strokeColor = .clear
        rule.position = CGPoint(x: 0, y: size.height / 2 - 56)
        rule.zPosition = 3
        addChild(rule)

        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = "PLAYER STATS"
        label.fontSize = 26
        label.fontColor = .white
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: size.height / 2 - 28)
        label.zPosition = 4
        addChild(label)
    }

    // MARK: - Stats Cards
    private func addStatsCards() {
        let defaults       = UserDefaults.standard
        let bestTime       = defaults.double(forKey: PersistenceKey.bestSurvivalTime)
        let dataBits       = defaults.integer(forKey: PersistenceKey.totalDataBitsBank)
        let highestLevel   = max(1, defaults.integer(forKey: PersistenceKey.highestLevelReached))

        let cards: [(icon: String, title: String, value: String, accent: SKColor)] = [
            (
                "⏱",
                "BEST SURVIVAL TIME",
                formattedTime(bestTime),
                SKColor(red: 0.0, green: 0.95, blue: 0.75, alpha: 1.0)
            ),
            (
                "⬡",
                "TOTAL DATA BITS",
                "\(dataBits)",
                SKColor(red: 0.2, green: 0.7, blue: 1.0, alpha: 1.0)
            ),
            (
                "⬆",
                "HIGHEST LEVEL REACHED",
                "LEVEL \(highestLevel)",
                SKColor(red: 1.0, green: 0.75, blue: 0.1, alpha: 1.0)
            ),
        ]

        let cardW: CGFloat = size.width * 0.72
        let cardH: CGFloat = 74
        let startY: CGFloat = size.height * 0.18
        let gap:    CGFloat = 90

        for (i, card) in cards.enumerated() {
            let cardY = startY - CGFloat(i) * gap
            addCard(icon: card.icon, title: card.title, value: card.value,
                    accent: card.accent, width: cardW, height: cardH,
                    position: CGPoint(x: 0, y: cardY))
        }
    }

    private func addCard(icon: String, title: String, value: String,
                         accent: SKColor, width: CGFloat, height: CGFloat,
                         position: CGPoint) {
        // Panel
        let panel = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: 14)
        panel.fillColor = SKColor(white: 0.07, alpha: 0.95)
        panel.strokeColor = SKColor(white: 0.18, alpha: 1.0)
        panel.lineWidth = 1.5
        panel.position = position
        panel.zPosition = 5
        addChild(panel)

        // Left accent bar
        let bar = SKShapeNode(rectOf: CGSize(width: 4, height: height - 20), cornerRadius: 2)
        bar.fillColor = accent
        bar.strokeColor = .clear
        bar.position = CGPoint(x: -width / 2 + 10, y: 0)
        bar.zPosition = 6
        panel.addChild(bar)

        // Icon
        let iconLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        iconLabel.text = icon
        iconLabel.fontSize = 22
        iconLabel.fontColor = accent
        iconLabel.horizontalAlignmentMode = .left
        iconLabel.verticalAlignmentMode = .center
        iconLabel.position = CGPoint(x: -width / 2 + 28, y: 4)
        iconLabel.zPosition = 6
        panel.addChild(iconLabel)

        // Stat title
        let titleLabel = SKLabelNode(fontNamed: "AvenirNext-Regular")
        titleLabel.text = title
        titleLabel.fontSize = 11
        titleLabel.fontColor = SKColor(white: 0.45, alpha: 1.0)
        titleLabel.horizontalAlignmentMode = .left
        titleLabel.verticalAlignmentMode = .center
        titleLabel.position = CGPoint(x: -width / 2 + 58, y: 14)
        titleLabel.zPosition = 6
        panel.addChild(titleLabel)

        // Stat value
        let valueLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        valueLabel.text = value
        valueLabel.fontSize = 22
        valueLabel.fontColor = .white
        valueLabel.horizontalAlignmentMode = .left
        valueLabel.verticalAlignmentMode = .center
        valueLabel.position = CGPoint(x: -width / 2 + 58, y: -14)
        valueLabel.zPosition = 6
        panel.addChild(valueLabel)
    }

    // MARK: - Reset Button
    private func addResetButton() {
        let btnY: CGFloat = -size.height * 0.28

        let btn = SKShapeNode(rectOf: CGSize(width: 180, height: 40), cornerRadius: 10)
        btn.fillColor = SKColor(white: 0.1, alpha: 1.0)
        btn.strokeColor = SKColor(white: 0.3, alpha: 1.0)
        btn.lineWidth = 1.5
        btn.position = CGPoint(x: 0, y: btnY)
        btn.zPosition = 5
        btn.name = "resetButton"
        addChild(btn)

        let lbl = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        lbl.text = "RESET PROGRESS"
        lbl.fontSize = 13
        lbl.fontColor = SKColor(red: 1.0, green: 0.35, blue: 0.35, alpha: 1.0)
        lbl.horizontalAlignmentMode = .center
        lbl.verticalAlignmentMode = .center
        lbl.position = CGPoint.zero
        lbl.isUserInteractionEnabled = false
        btn.addChild(lbl)
    }

    // MARK: - Back Button
    private func addBackButton() {
        let btn = SKShapeNode(rectOf: CGSize(width: 100, height: 38), cornerRadius: 10)
        btn.fillColor = SKColor(white: 0.1, alpha: 0.9)
        btn.strokeColor = SKColor(white: 0.3, alpha: 1.0)
        btn.lineWidth = 1.5
        btn.position = CGPoint(x: -size.width / 2 + 74, y: size.height / 2 - 28)
        btn.zPosition = 10
        btn.name = "backButton"
        addChild(btn)

        let lbl = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        lbl.text = "← BACK"
        lbl.fontSize = 14
        lbl.fontColor = SKColor(red: 0.0, green: 0.95, blue: 0.75, alpha: 1.0)
        lbl.horizontalAlignmentMode = .center
        lbl.verticalAlignmentMode = .center
        lbl.position = CGPoint.zero
        lbl.isUserInteractionEnabled = false
        btn.addChild(lbl)
    }

    // MARK: - Reset Confirmation Overlay
    private func showResetConfirmation() {
        guard childNode(withName: "confirmOverlay") == nil else { return }

        let overlay = SKNode()
        overlay.name = "confirmOverlay"
        overlay.zPosition = 50

        let dim = SKShapeNode(rectOf: CGSize(width: size.width, height: size.height))
        dim.fillColor = SKColor(white: 0.0, alpha: 0.7)
        dim.strokeColor = .clear
        dim.position = .zero
        overlay.addChild(dim)

        let panel = SKShapeNode(rectOf: CGSize(width: 300, height: 160), cornerRadius: 16)
        panel.fillColor = SKColor(white: 0.08, alpha: 0.98)
        panel.strokeColor = SKColor(white: 0.25, alpha: 1.0)
        panel.lineWidth = 1.5
        panel.position = .zero
        overlay.addChild(panel)

        let title = SKLabelNode(fontNamed: "AvenirNext-Bold")
        title.text = "Reset Progress?"
        title.fontSize = 22
        title.fontColor = .white
        title.horizontalAlignmentMode = .center
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: 0, y: 42)
        panel.addChild(title)

        let sub = SKLabelNode(fontNamed: "AvenirNext-Regular")
        sub.text = "This cannot be undone."
        sub.fontSize = 14
        sub.fontColor = SKColor(white: 0.5, alpha: 1.0)
        sub.horizontalAlignmentMode = .center
        sub.verticalAlignmentMode = .center
        sub.position = CGPoint(x: 0, y: 16)
        panel.addChild(sub)

        // Confirm
        let confirmBtn = SKShapeNode(rectOf: CGSize(width: 120, height: 42), cornerRadius: 10)
        confirmBtn.fillColor = SKColor(red: 0.6, green: 0.05, blue: 0.05, alpha: 1.0)
        confirmBtn.strokeColor = .clear
        confirmBtn.position = CGPoint(x: -70, y: -36)
        confirmBtn.name = "confirmReset"
        panel.addChild(confirmBtn)

        let confirmLbl = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        confirmLbl.text = "Reset"
        confirmLbl.fontSize = 17
        confirmLbl.fontColor = .white
        confirmLbl.horizontalAlignmentMode = .center
        confirmLbl.verticalAlignmentMode = .center
        confirmLbl.position = .zero
        confirmLbl.isUserInteractionEnabled = false
        confirmBtn.addChild(confirmLbl)

        // Cancel
        let cancelBtn = SKShapeNode(rectOf: CGSize(width: 120, height: 42), cornerRadius: 10)
        cancelBtn.fillColor = SKColor(white: 0.18, alpha: 1.0)
        cancelBtn.strokeColor = .clear
        cancelBtn.position = CGPoint(x: 70, y: -36)
        cancelBtn.name = "cancelReset"
        panel.addChild(cancelBtn)

        let cancelLbl = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        cancelLbl.text = "Cancel"
        cancelLbl.fontSize = 17
        cancelLbl.fontColor = .white
        cancelLbl.horizontalAlignmentMode = .center
        cancelLbl.verticalAlignmentMode = .center
        cancelLbl.position = .zero
        cancelLbl.isUserInteractionEnabled = false
        cancelBtn.addChild(cancelLbl)

        addChild(overlay)
    }

    private func dismissConfirmation() {
        childNode(withName: "confirmOverlay")?.removeFromParent()
    }

    private func resetProgress() {
        let defaults = UserDefaults.standard
        defaults.set(0.0, forKey: PersistenceKey.bestSurvivalTime)
        defaults.set(0,   forKey: PersistenceKey.totalDataBitsBank)
        defaults.set(1,   forKey: PersistenceKey.highestLevelReached)
        dismissConfirmation()
        // Reload scene to refresh displayed values
        let fresh = PlayerStatsScene(size: size)
        fresh.scaleMode = scaleMode
        view?.presentScene(fresh, transition: SKTransition.fade(
            with: SKColor(red: 0.04, green: 0.06, blue: 0.10, alpha: 1.0),
            duration: 0.25
        ))
    }

    // MARK: - Entry Animation
    private func fadeIn() {
        self.alpha = 0
        run(SKAction.fadeIn(withDuration: 0.4))
    }

    // MARK: - Input
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let tapped   = nodes(at: location)
        let names    = tapped.compactMap { $0.name }

        // Confirmation overlay buttons
        if names.contains("confirmReset") {
            resetProgress()
            return
        }
        if names.contains("cancelReset") {
            dismissConfirmation()
            return
        }

        // Block other taps while overlay is showing
        if childNode(withName: "confirmOverlay") != nil { return }

        if names.contains("resetButton") {
            showResetConfirmation()
            return
        }

        if names.contains("backButton") {
            let menu = MainMenuScene(size: size)
            menu.scaleMode = scaleMode
            view?.presentScene(menu, transition: SKTransition.fade(
                with: SKColor(red: 0.04, green: 0.06, blue: 0.10, alpha: 1.0),
                duration: 0.35
            ))
            return
        }
    }

    // MARK: - Helpers
    private func formattedTime(_ time: TimeInterval) -> String {
        let total   = Int(max(0, time.rounded(.down)))
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
