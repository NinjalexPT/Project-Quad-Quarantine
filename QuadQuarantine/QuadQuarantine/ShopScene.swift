//
//  ShopScene.swift
//  QuadQuarantine
//
//  Loja de upgrades permanentes — acedida a partir do Menu Principal.
//  Moeda: Bits (ouro) acumulados durante as runs.
//

import SpriteKit

class ShopScene: SKScene {

    // MARK: - Layout constants
    private let cardWidth:  CGFloat = 440
    private let cardHeight: CGFloat = 90
    private let cardGap:    CGFloat = 14

    // MARK: - Scroll state
    private var scrollContainer: SKNode!
    private var clipAreaHeight:  CGFloat = 0
    private var contentHeight:   CGFloat = 0
    private var scrollMin:       CGFloat = 0
    private var isDragging       = false
    private var touchStartY:     CGFloat = 0
    private var touchScrollStart:CGFloat = 0
    private var scrollVelocity:  CGFloat = 0

    // MARK: - Lifecycle
    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = SKColor(red: 0.04, green: 0.06, blue: 0.10, alpha: 1.0)
        addGridBackground()
        addTopBar()
        buildScrollArea()
        addBackButton()
        self.alpha = 0
        run(SKAction.fadeIn(withDuration: 0.25))
    }

    // MARK: - Grid background
    private func addGridBackground() {
        let cols = Int(size.width  / 40) + 2
        let rows = Int(size.height / 40) + 2
        for col in 0..<cols {
            for row in 0..<rows {
                let dot = SKShapeNode(circleOfRadius: 1.2)
                dot.fillColor  = SKColor(white: 1.0, alpha: 0.06)
                dot.strokeColor = .clear
                dot.position   = CGPoint(x: -size.width/2 + CGFloat(col)*40,
                                         y: -size.height/2 + CGFloat(row)*40)
                dot.zPosition  = -10
                addChild(dot)
            }
        }
        addCorner(x: -size.width/2 + 28, y:  size.height/2 - 70, dx:  36, dy: -36)
        addCorner(x:  size.width/2 - 28, y: -size.height/2 + 28, dx: -36, dy:  36)
    }

    private func addCorner(x: CGFloat, y: CGFloat, dx: CGFloat, dy: CGFloat) {
        let s = SKShapeNode(); let p = CGMutablePath()
        p.move(to: CGPoint(x: x, y: y + dy))
        p.addLine(to: CGPoint(x: x, y: y))
        p.addLine(to: CGPoint(x: x + dx, y: y))
        s.path = p
        s.strokeColor = SKColor(red: 0.0, green: 0.9, blue: 0.7, alpha: 0.55)
        s.lineWidth = 2; s.zPosition = 1; addChild(s)
    }

    // MARK: - Top bar
    private func addTopBar() {
        let barH: CGFloat = 58
        let barY = size.height/2 - barH/2

        let bg = SKShapeNode(rectOf: CGSize(width: size.width, height: barH))
        bg.fillColor = SKColor(white: 0.0, alpha: 0.35); bg.strokeColor = .clear
        bg.position = CGPoint(x: 0, y: barY); bg.zPosition = 2; addChild(bg)

        let rule = SKShapeNode(rectOf: CGSize(width: size.width, height: 1.5))
        rule.fillColor = SKColor(red: 0.0, green: 0.95, blue: 0.75, alpha: 0.4)
        rule.strokeColor = .clear
        rule.position = CGPoint(x: 0, y: barY - barH/2); rule.zPosition = 3; addChild(rule)

        let title = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        title.text = "UPGRADE SHOP"; title.fontSize = 25; title.fontColor = .white
        title.horizontalAlignmentMode = .center; title.verticalAlignmentMode = .center
        title.position = CGPoint(x: 0, y: barY); title.zPosition = 4; addChild(title)

        // Bits badge
        let bitsBox = SKShapeNode(rectOf: CGSize(width: 148, height: 34), cornerRadius: 9)
        bitsBox.fillColor  = SKColor(red: 0.8, green: 0.55, blue: 0.0, alpha: 0.18)
        bitsBox.strokeColor = SKColor(red: 1.0, green: 0.82, blue: 0.0, alpha: 0.75)
        bitsBox.lineWidth  = 1.5
        bitsBox.position   = CGPoint(x: size.width/2 - 98, y: barY)
        bitsBox.zPosition  = 4; addChild(bitsBox)

        let bitsLbl = SKLabelNode(fontNamed: "AvenirNext-Bold")
        bitsLbl.name = "bitsLabel"
        bitsLbl.text = "\u{2B21} \(UpgradeManager.shared.bitsBank) BITS"
        bitsLbl.fontSize = 15
        bitsLbl.fontColor = SKColor(red: 1.0, green: 0.85, blue: 0.0, alpha: 1.0)
        bitsLbl.verticalAlignmentMode   = .center
        bitsLbl.horizontalAlignmentMode = .center
        bitsLbl.position = CGPoint(x: size.width/2 - 98, y: barY)
        bitsLbl.zPosition = 5; addChild(bitsLbl)
    }

    // MARK: - Back button
    private func addBackButton() {
        let barY = size.height/2 - 29
        let btn = SKShapeNode(rectOf: CGSize(width: 112, height: 38), cornerRadius: 10)
        btn.fillColor  = SKColor(white: 0.1, alpha: 0.9)
        btn.strokeColor = SKColor(white: 0.45, alpha: 0.7)
        btn.lineWidth  = 1.5
        btn.position   = CGPoint(x: -size.width/2 + 74, y: barY)
        btn.zPosition  = 20; btn.name = "backButton"; addChild(btn)
        let lbl = SKLabelNode(fontNamed: "AvenirNext-Bold")
        lbl.text = "\u{2190} BACK"; lbl.fontSize = 15; lbl.fontColor = .white
        lbl.verticalAlignmentMode   = .center
        lbl.horizontalAlignmentMode = .center
        lbl.isUserInteractionEnabled = false
        btn.addChild(lbl)
    }

    // MARK: - Scroll area
    private func buildScrollArea() {
        let topBarH:   CGFloat = 58
        let bottomPad: CGFloat = 16
        clipAreaHeight = size.height - topBarH - bottomPad
        let clipY: CGFloat = -topBarH/2 + bottomPad/2 - 2

        let crop = SKCropNode()
        crop.position  = CGPoint(x: 0, y: clipY)
        crop.zPosition = 10
        let mask = SKSpriteNode(color: .white,
                                size: CGSize(width: size.width, height: clipAreaHeight))
        crop.maskNode = mask
        addChild(crop)

        scrollContainer = SKNode()
        scrollContainer.name = "scrollContainer"
        crop.addChild(scrollContainer)

        rebuildCards()
    }

    private func rebuildCards() {
        scrollContainer.removeAllChildren()

        let catalogue = UpgradeManager.shared.catalogue
        contentHeight = CGFloat(catalogue.count) * (cardHeight + cardGap) + cardGap
        scrollMin = max(0, contentHeight - clipAreaHeight)

        let startY = clipAreaHeight/2 - cardGap - cardHeight/2

        for (i, def) in catalogue.enumerated() {
            let card = makeCard(def: def)
            card.position = CGPoint(x: 0, y: startY - CGFloat(i) * (cardHeight + cardGap))
            scrollContainer.addChild(card)
        }

        // Refresh bits label too
        if let lbl = childNode(withName: "bitsLabel") as? SKLabelNode {
            lbl.text = "\u{2B21} \(UpgradeManager.shared.bitsBank) BITS"
        }
    }

    // MARK: - Card factory
    private func makeCard(def: UpgradeManager.UpgradeDef) -> SKNode {
        let mgr = UpgradeManager.shared
        let tier    = mgr.tier(for: def.key)
        let isMaxed = tier >= def.maxTier
        let canBuy  = mgr.canPurchase(def)

        let container = SKNode()
        container.name = "card_\(def.key)"

        // Panel background
        let panel = SKShapeNode(rectOf: CGSize(width: cardWidth, height: cardHeight),
                                cornerRadius: 14)
        panel.fillColor  = SKColor(white: 0.07, alpha: 0.96)
        panel.strokeColor = isMaxed
            ? SKColor(red: 0.0, green: 0.9,  blue: 0.7,  alpha: 0.75)
            : (canBuy ? SKColor(red: 1.0, green: 0.82, blue: 0.0, alpha: 0.45)
                      : SKColor(white: 0.16, alpha: 1.0))
        panel.lineWidth  = isMaxed ? 2.0 : 1.5
        container.addChild(panel)

        // Left accent bar
        let accentClr: SKColor = isMaxed
            ? SKColor(red: 0.0, green: 0.95, blue: 0.75, alpha: 1.0)
            : SKColor(red: 1.0, green: 0.82, blue: 0.0,  alpha: 0.85)
        let bar = SKShapeNode(rectOf: CGSize(width: 4, height: cardHeight - 22), cornerRadius: 2)
        bar.fillColor   = accentClr; bar.strokeColor = .clear
        bar.position    = CGPoint(x: -cardWidth/2 + 10, y: 0)
        container.addChild(bar)

        // Icon
        let iconLbl = SKLabelNode(fontNamed: "AvenirNext-Bold")
        iconLbl.text = def.icon; iconLbl.fontSize = 26; iconLbl.fontColor = accentClr
        iconLbl.verticalAlignmentMode   = .center
        iconLbl.horizontalAlignmentMode = .center
        iconLbl.position = CGPoint(x: -cardWidth/2 + 36, y: 4)
        container.addChild(iconLbl)

        // Name
        let nameLbl = SKLabelNode(fontNamed: "AvenirNext-Bold")
        nameLbl.text = def.name; nameLbl.fontSize = 16; nameLbl.fontColor = .white
        nameLbl.horizontalAlignmentMode = .left; nameLbl.verticalAlignmentMode = .center
        nameLbl.position = CGPoint(x: -cardWidth/2 + 58, y: 22)
        container.addChild(nameLbl)

        // Flavor text
        let flavorLbl = SKLabelNode(fontNamed: "AvenirNext-Regular")
        flavorLbl.text = def.flavorText; flavorLbl.fontSize = 12
        flavorLbl.fontColor = SKColor(white: 0.48, alpha: 1.0)
        flavorLbl.horizontalAlignmentMode = .left; flavorLbl.verticalAlignmentMode = .center
        flavorLbl.position = CGPoint(x: -cardWidth/2 + 58, y: 4)
        container.addChild(flavorLbl)

        // Stat line
        let statLbl = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        statLbl.fontSize = 12
        statLbl.horizontalAlignmentMode = .left; statLbl.verticalAlignmentMode = .center
        statLbl.position = CGPoint(x: -cardWidth/2 + 58, y: -14)
        if isMaxed {
            statLbl.text = "MAX — \(def.statLine(tier))"
            statLbl.fontColor = SKColor(red: 0.0, green: 0.95, blue: 0.75, alpha: 1.0)
        } else if tier > 0 {
            statLbl.text = "Now: \(def.statLine(tier))   \u{2192}   Next: \(def.statLine(tier + 1))"
            statLbl.fontColor = SKColor(white: 0.65, alpha: 1.0)
        } else {
            statLbl.text = "Next: \(def.statLine(1))"
            statLbl.fontColor = SKColor(white: 0.50, alpha: 1.0)
        }
        container.addChild(statLbl)

        // Tier pips
        let pipStart = -cardWidth/2 + 58
        for pip in 0..<def.maxTier {
            let filled = pip < tier
            let c = SKShapeNode(circleOfRadius: 5)
            c.fillColor   = filled ? accentClr : SKColor(white: 0.18, alpha: 1.0)
            c.strokeColor = filled ? .clear : SKColor(white: 0.28, alpha: 1.0)
            c.lineWidth   = 1
            c.position    = CGPoint(x: pipStart + CGFloat(pip) * 15, y: -30)
            container.addChild(c)
        }

        // Buy / MAXED indicator
        if isMaxed {
            let mx = SKLabelNode(fontNamed: "AvenirNext-Heavy")
            mx.text = "\u{2713} MAXED"; mx.fontSize = 16
            mx.fontColor = SKColor(red: 0.0, green: 0.95, blue: 0.75, alpha: 1.0)
            mx.verticalAlignmentMode   = .center
            mx.horizontalAlignmentMode = .center
            mx.position = CGPoint(x: cardWidth/2 - 66, y: 0)
            container.addChild(mx)
        } else {
            let cost = def.costs[tier]
            let btnW: CGFloat = 114; let btnH: CGFloat = 42
            let btn = SKShapeNode(rectOf: CGSize(width: btnW, height: btnH), cornerRadius: 10)
            btn.fillColor  = canBuy
                ? SKColor(red: 0.75, green: 0.50, blue: 0.0, alpha: 0.90)
                : SKColor(white: 0.11, alpha: 1.0)
            btn.strokeColor = canBuy
                ? SKColor(red: 1.0,  green: 0.82, blue: 0.0, alpha: 1.0)
                : SKColor(white: 0.22, alpha: 1.0)
            btn.lineWidth  = 1.5
            btn.position   = CGPoint(x: cardWidth/2 - btnW/2 - 14, y: 0)
            btn.name       = "buyBtn_\(def.key)"
            container.addChild(btn)

            let costLbl = SKLabelNode(fontNamed: "AvenirNext-Bold")
            costLbl.text = "\u{2B21} \(cost)"
            costLbl.fontSize = 15
            costLbl.fontColor = canBuy ? .white : SKColor(white: 0.32, alpha: 1.0)
            costLbl.verticalAlignmentMode   = .center
            costLbl.horizontalAlignmentMode = .center
            costLbl.isUserInteractionEnabled = false
            btn.addChild(costLbl)
        }

        return container
    }

    // MARK: - Touch
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        touchStartY     = t.location(in: self).y
        touchScrollStart = scrollContainer.position.y
        isDragging      = false
        scrollVelocity  = 0
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        // deslizar para cima → itens sobem → ver itens abaixo (comportamento iOS padrão)
        let dy = t.location(in: self).y - touchStartY
        if abs(dy) > 6 { isDragging = true }
        if isDragging {
            let newY = touchScrollStart + dy
            scrollContainer.position.y = max(0, min(scrollMin, newY))
            scrollVelocity = t.location(in: self).y - t.previousLocation(in: self).y
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        if !isDragging { handleTap(at: t.location(in: self)) }
        isDragging = false
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        isDragging = false; scrollVelocity = 0
    }

    override func update(_ currentTime: TimeInterval) {
        guard !isDragging, abs(scrollVelocity) > 0.5 else { return }
        scrollContainer.position.y += scrollVelocity
        scrollContainer.position.y  = max(0, min(scrollMin, scrollContainer.position.y))
        scrollVelocity *= 0.90
    }

    // MARK: - Tap routing
    private func handleTap(at loc: CGPoint) {
        let hit = nodes(at: loc)

        // Back
        if hit.contains(where: { $0.name == "backButton" || $0.parent?.name == "backButton" }) {
            let menu = MainMenuScene(size: size); menu.scaleMode = scaleMode
            view?.presentScene(menu, transition: SKTransition.fade(
                with: SKColor(red: 0.04, green: 0.06, blue: 0.10, alpha: 1), duration: 0.3))
            return
        }

        // Buy buttons (walk up the tree)
        for node in hit {
            var cur: SKNode? = node
            while let c = cur {
                if let name = c.name, name.hasPrefix("buyBtn_") {
                    attemptPurchase(key: String(name.dropFirst("buyBtn_".count)))
                    return
                }
                cur = c.parent
            }
        }
    }

    private func attemptPurchase(key: String) {
        guard let def = UpgradeManager.shared.catalogue.first(where: { $0.key == key })
        else { return }

        if UpgradeManager.shared.purchase(def) {
            flashScreen(color: SKColor(red: 1.0, green: 0.82, blue: 0.0, alpha: 0.10))
            rebuildCards()
        } else {
            flashScreen(color: SKColor(red: 1.0, green: 0.2, blue: 0.1, alpha: 0.07))
        }
    }

    private func flashScreen(color: SKColor) {
        let f = SKShapeNode(rectOf: CGSize(width: size.width, height: size.height))
        f.fillColor = color; f.strokeColor = .clear; f.zPosition = 50; addChild(f)
        f.run(SKAction.sequence([SKAction.fadeOut(withDuration: 0.28), .removeFromParent()]))
    }
}
