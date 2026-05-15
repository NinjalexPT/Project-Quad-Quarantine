import SpriteKit
import GameplayKit
import AVFoundation

// MARK: - Categorias de Física
struct PhysicsCategory {
    static let none: UInt32     = 0
    static let player: UInt32   = 0b1
    static let enemy: UInt32    = 0b10
    static let bullet: UInt32   = 0b100
    static let dataBit: UInt32  = 0b1000
}

class GameScene: SKScene, SKPhysicsContactDelegate {
    private enum PersistenceKey {
        static let bestSurvivalTime   = "bestSurvivalTime"
        static let totalDataBitsBank  = "totalDataBitsBank"
        static let highestLevelReached = "highestLevelReached"
    }

    enum GameState { case running, perkSelection, gameOver, paused }
    enum PerkType: String, CaseIterable {
        case speed = "Speed"; case damage = "Damage"; case fireRate = "Fire Rate"
    }

    // MARK: - Propriedades
    var player: SKSpriteNode!
    var joystick: Joystick!
    let gameCamera = SKCameraNode()
    var gameState: GameState = .running
    private let gameOverOverlayName  = "gameOverOverlay"
    private let perkOverlayName      = "perkOverlay"
    private let autoFireActionKey    = "autoFireAction"
    private var autoFireInterval: TimeInterval = 0.45
    private let bulletSpeed: CGFloat  = 520
    private let bulletRange: CGFloat  = 900
    private let dataBitPickupRadius: CGFloat = 8
    private let xpPerDataBit: Int   = 1
    private let baseXPToLevelUp: Int = 5
    private let xpStepPerLevel: Int  = 3
    private var currentLevel: Int   = 1
    private var currentXP: Int      = 0
    private var xpToNextLevel: Int  = 5
    private var xpBarFillNode: SKShapeNode!
    private var levelLabel: SKLabelNode!
    private var xpLabel: SKLabelNode!
    private var playerMoveSpeed: CGFloat = 5.0
    private var bulletDamage: Int = 1
    private var pendingPerkSelections: Int = 0
    private var bestSurvivalTime: TimeInterval = 0
    private var totalDataBitsBank: Int = 0
    private var highestLevelReached: Int = 1
    private var runStartTime: TimeInterval?
    private var currentRunSurvivalTime: TimeInterval = 0
    private var currentRunDataBitsCollected: Int = 0
    private var bestTimeLabel: SKLabelNode!
    private var pauseButton: SKShapeNode!

    // Animação do player
    private var playerIdleFrames: [SKTexture] = []
    private var playerRunFrames:  [SKTexture] = []
    private var isPlayerMoving = false

    // MARK: - Helpers de Animação
    static func makeFrames(from imageName: String, frameCount: Int) -> [SKTexture] {
        let strip = SKTexture(imageNamed: imageName)
        strip.filteringMode = .nearest
        let fw = 1.0 / CGFloat(frameCount)
        return (0..<frameCount).map { i in
            let t = SKTexture(rect: CGRect(x: CGFloat(i) * fw, y: 0, width: fw, height: 1.0), in: strip)
            t.filteringMode = .nearest
            return t
        }
    }

    // MARK: - Ciclo de Vida
    override func didMove(to view: SKView) {
        loadPersistentProgress()
        self.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        self.backgroundColor = SKColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1.0)
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self
        addChild(gameCamera)
        self.camera = gameCamera

        setupBackground()
        setupPlayer()
        setupJoystick()
        setupHUD()
        startEnemySpawner()
        startAutoFire()
        refreshBestTimeUI()
    }

    // MARK: - Background
    func setupBackground() {
        // Chão: tile de sBg.png
        let tileSize: CGFloat = 64
        let count = 52  // cobre 3328px em cada eixo
        let half = CGFloat(count) * tileSize / 2.0
        for col in 0..<count {
            for row in 0..<count {
                let tile = SKSpriteNode(imageNamed: "sBg")
                tile.size  = CGSize(width: tileSize, height: tileSize)
                tile.texture?.filteringMode = .nearest
                tile.position = CGPoint(
                    x: CGFloat(col) * tileSize - half + tileSize / 2,
                    y: CGFloat(row) * tileSize - half + tileSize / 2
                )
                tile.zPosition = -10
                addChild(tile)
            }
        }

        // Mapa central
        let mapNode = SKSpriteNode(imageNamed: "sMap")
        mapNode.size = CGSize(width: 320, height: 320)
        mapNode.texture?.filteringMode = .nearest
        mapNode.position = .zero
        mapNode.zPosition = -9
        addChild(mapNode)
    }

    // MARK: - Setup Player
    func setupPlayer() {
        playerIdleFrames = GameScene.makeFrames(from: "sPlayerIdle_strip4", frameCount: 4)
        playerRunFrames  = GameScene.makeFrames(from: "sPlayerRun_strip7",  frameCount: 7)

        player = SKSpriteNode(texture: playerIdleFrames[0])
        player.size = CGSize(width: 40, height: 40)
        player.position = .zero
        player.zPosition = 10

        player.physicsBody = SKPhysicsBody(rectangleOf: player.size)
        player.physicsBody?.affectedByGravity = false
        player.physicsBody?.allowsRotation    = false
        player.physicsBody?.categoryBitMask   = PhysicsCategory.player
        player.physicsBody?.collisionBitMask  = PhysicsCategory.none
        player.physicsBody?.contactTestBitMask = PhysicsCategory.enemy | PhysicsCategory.dataBit
        player.physicsBody?.usesPreciseCollisionDetection = true

        addChild(player)

        // Gun
        let gun = SKSpriteNode(imageNamed: "sGun")
        gun.texture?.filteringMode = .nearest
        gun.size = CGSize(width: 40, height: 20)
        gun.position = CGPoint(x: 18, y: 0)
        gun.zPosition = 1
        gun.name = "gun"
        player.addChild(gun)

        // Idle animation
        playPlayerIdle()
    }

    private func playPlayerIdle() {
        guard !isPlayerMoving else { return }
        if player.action(forKey: "anim") == nil {
            let anim = SKAction.animate(with: playerIdleFrames, timePerFrame: 0.15)
            player.run(SKAction.repeatForever(anim), withKey: "anim")
        }
    }

    private func playPlayerRun() {
        guard isPlayerMoving else { return }
        player.removeAction(forKey: "anim")
        let anim = SKAction.animate(with: playerRunFrames, timePerFrame: 0.1)
        player.run(SKAction.repeatForever(anim), withKey: "anim")
    }

    func setupJoystick() {
        joystick = Joystick(radius: 60)
        joystick.position = CGPoint(
            x: -size.width / 2 + 140,
            y: -size.height / 2 + 100
        )
        joystick.zPosition = 100
        gameCamera.addChild(joystick)
    }

    func setupHUD() {
        let barWidth: CGFloat = 240
        let barHeight: CGFloat = 16
        let hudY = size.height / 2 - 56

        let xpBackground = SKShapeNode(rectOf: CGSize(width: barWidth, height: barHeight), cornerRadius: 8)
        xpBackground.fillColor = SKColor(white: 0.2, alpha: 0.9)
        xpBackground.strokeColor = SKColor(white: 0.85, alpha: 1.0)
        xpBackground.lineWidth = 2
        xpBackground.position = CGPoint(x: 0, y: hudY)
        xpBackground.zPosition = 140
        gameCamera.addChild(xpBackground)

        xpBarFillNode = SKShapeNode(rectOf: CGSize(width: barWidth - 4, height: barHeight - 4), cornerRadius: 6)
        xpBarFillNode.fillColor = .systemGreen
        xpBarFillNode.strokeColor = .clear
        xpBarFillNode.position = CGPoint(x: 0, y: hudY)
        xpBarFillNode.zPosition = 141
        gameCamera.addChild(xpBarFillNode)

        levelLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        levelLabel.fontSize = 16
        levelLabel.fontColor = .white
        levelLabel.horizontalAlignmentMode = .left
        levelLabel.position = CGPoint(x: -barWidth / 2, y: hudY + 18)
        levelLabel.zPosition = 142
        gameCamera.addChild(levelLabel)

        xpLabel = SKLabelNode(fontNamed: "AvenirNext-Regular")
        xpLabel.fontSize = 14
        xpLabel.fontColor = .white
        xpLabel.horizontalAlignmentMode = .right
        xpLabel.position = CGPoint(x: barWidth / 2, y: hudY + 18)
        xpLabel.zPosition = 142
        gameCamera.addChild(xpLabel)

        bestTimeLabel = SKLabelNode(fontNamed: "AvenirNext-Regular")
        bestTimeLabel.fontSize = 14
        bestTimeLabel.fontColor = .systemYellow
        bestTimeLabel.horizontalAlignmentMode = .center
        bestTimeLabel.position = CGPoint(x: 0, y: hudY + 38)
        bestTimeLabel.zPosition = 142
        gameCamera.addChild(bestTimeLabel)

        pauseButton = SKShapeNode(rectOf: CGSize(width: 44, height: 44), cornerRadius: 8)
        pauseButton.fillColor = SKColor(white: 0.15, alpha: 0.85)
        pauseButton.strokeColor = SKColor(white: 0.9, alpha: 1.0)
        pauseButton.lineWidth = 2
        pauseButton.position = CGPoint(x: size.width / 2 - 38, y: hudY + 38)
        pauseButton.zPosition = 150
        pauseButton.name = "pauseButton"
        let pauseSymbol = SKLabelNode(fontNamed: "AvenirNext-Bold")
        pauseSymbol.text = "❚❚"
        pauseSymbol.fontSize = 26
        pauseSymbol.fontColor = .white
        pauseSymbol.verticalAlignmentMode = .center
        pauseSymbol.horizontalAlignmentMode = .center
        pauseSymbol.isUserInteractionEnabled = false
        pauseButton.addChild(pauseSymbol)
        gameCamera.addChild(pauseButton)

        updateXPUI()
    }

    // MARK: - Inimigos
    func startEnemySpawner() {
        let spawn = SKAction.run { [weak self] in self?.spawnEnemy() }
        let wait  = SKAction.wait(forDuration: 1.5)
        run(SKAction.repeatForever(SKAction.sequence([spawn, wait])), withKey: "enemySpawner")
    }

    func spawnEnemy() {
        let enemyFrames = GameScene.makeFrames(from: "sEnemy_strip7", frameCount: 7)
        let enemy = SKSpriteNode(texture: enemyFrames[0])
        enemy.size = CGSize(width: 40, height: 40)
        enemy.name = "enemy"
        enemy.zPosition = 9

        enemy.physicsBody = SKPhysicsBody(rectangleOf: enemy.size)
        enemy.physicsBody?.affectedByGravity = false
        enemy.physicsBody?.allowsRotation    = false
        enemy.physicsBody?.categoryBitMask   = PhysicsCategory.enemy
        enemy.physicsBody?.collisionBitMask  = PhysicsCategory.none
        enemy.physicsBody?.contactTestBitMask = PhysicsCategory.player
        enemy.physicsBody?.usesPreciseCollisionDetection = true
        enemy.userData = NSMutableDictionary()
        enemy.userData?["health"] = 1

        let walkAnim = SKAction.animate(with: enemyFrames, timePerFrame: 0.1)
        enemy.run(SKAction.repeatForever(walkAnim), withKey: "walkAnim")

        let margin: CGFloat = 80
        let camX = gameCamera.position.x
        let camY = gameCamera.position.y
        let hw = size.width / 2
        let hh = size.height / 2

        switch Int.random(in: 0...3) {
        case 0: enemy.position = CGPoint(x: CGFloat.random(in: camX-hw...camX+hw), y: camY+hh+margin)
        case 1: enemy.position = CGPoint(x: CGFloat.random(in: camX-hw...camX+hw), y: camY-hh-margin)
        case 2: enemy.position = CGPoint(x: camX-hw-margin, y: CGFloat.random(in: camY-hh...camY+hh))
        default: enemy.position = CGPoint(x: camX+hw+margin, y: CGFloat.random(in: camY-hh...camY+hh))
        }

        addChild(enemy)
    }

    func spawnDataBit(at position: CGPoint) {
        let dataBit = SKShapeNode(circleOfRadius: dataBitPickupRadius)
        dataBit.name = "dataBit"
        dataBit.fillColor = .cyan
        dataBit.strokeColor = SKColor(white: 0.9, alpha: 1.0)
        dataBit.lineWidth = 1.5
        dataBit.position = position
        dataBit.zPosition = 40
        dataBit.physicsBody = SKPhysicsBody(circleOfRadius: dataBitPickupRadius)
        dataBit.physicsBody?.isDynamic   = false
        dataBit.physicsBody?.affectedByGravity = false
        dataBit.physicsBody?.categoryBitMask   = PhysicsCategory.dataBit
        dataBit.physicsBody?.collisionBitMask  = PhysicsCategory.none
        dataBit.physicsBody?.contactTestBitMask = PhysicsCategory.player
        dataBit.physicsBody?.usesPreciseCollisionDetection = true
        addChild(dataBit)
    }

    func collectDataBit(_ dataBitNode: SKNode?) {
        guard let dataBitNode else { return }
        dataBitNode.removeFromParent()
        currentRunDataBitsCollected += xpPerDataBit
        gainXP(xpPerDataBit)
    }

    func gainXP(_ amount: Int) {
        guard amount > 0 else { return }
        currentXP += amount
        while currentXP >= xpToNextLevel {
            currentXP -= xpToNextLevel
            currentLevel += 1
            xpToNextLevel = baseXPToLevelUp + ((currentLevel - 1) * xpStepPerLevel)
            showLevelUpFeedback()
            pendingPerkSelections += 1
        }
        updateXPUI()
        if gameState == .running, pendingPerkSelections > 0 { pauseForPerkSelection() }
    }

    func updateXPUI() {
        let normalizedXP = max(0, min(1, CGFloat(currentXP) / CGFloat(max(1, xpToNextLevel))))
        xpBarFillNode.xScale = normalizedXP
        levelLabel.text = "LEVEL \(currentLevel)"
        xpLabel.text = "\(currentXP)/\(xpToNextLevel) XP"
    }

    func showLevelUpFeedback() {
        let lbl = SKLabelNode(fontNamed: "AvenirNext-Bold")
        lbl.text = "LEVEL UP!"
        lbl.fontSize = 28
        lbl.fontColor = .systemYellow
        lbl.position = CGPoint(x: 0, y: size.height / 2 - 120)
        lbl.zPosition = 200
        lbl.alpha = 0
        gameCamera.addChild(lbl)
        let popIn  = SKAction.group([SKAction.scale(to: 1.15, duration: 0.12), SKAction.fadeIn(withDuration: 0.12)])
        let hold   = SKAction.wait(forDuration: 0.35)
        let fadeOut = SKAction.group([SKAction.scale(to: 1.0, duration: 0.18), SKAction.fadeOut(withDuration: 0.18)])
        lbl.run(SKAction.sequence([popIn, hold, fadeOut, .removeFromParent()]))
    }

    // MARK: - Perk Menu
    func pauseForPerkSelection() {
        guard gameState == .running else { return }
        joystick.reset(animated: false)
        gameState = .perkSelection
        isPaused = true
        showPerkMenuOverlay()
    }

    func resumeAfterPerkSelection() {
        joystick.reset(animated: false)
        isPaused = false
        removePerkMenuOverlay()
        if pendingPerkSelections > 0 {
            gameState = .running
            pauseForPerkSelection()
        } else {
            gameState = .running
        }
    }

    func showPerkMenuOverlay() {
        removePerkMenuOverlay()
        let overlay = SKNode()
        overlay.name = perkOverlayName
        overlay.zPosition = 320
        let dim = SKShapeNode(rectOf: CGSize(width: size.width, height: size.height))
        dim.fillColor = SKColor(white: 0.0, alpha: 0.75)
        dim.strokeColor = .clear
        overlay.addChild(dim)
        let panel = SKShapeNode(rectOf: CGSize(width: 360, height: 280), cornerRadius: 20)
        panel.fillColor = SKColor(white: 0.1, alpha: 0.95)
        panel.strokeColor = SKColor(white: 0.9, alpha: 1.0)
        panel.lineWidth = 2
        panel.position = CGPoint(x: 0, y: 16)
        overlay.addChild(panel)
        let title = SKLabelNode(fontNamed: "AvenirNext-Bold")
        title.text = "Choose a Perk"
        title.fontSize = 30
        title.fontColor = .white
        title.position = CGPoint(x: 0, y: 104)
        panel.addChild(title)
        let subtitle = SKLabelNode(fontNamed: "AvenirNext-Regular")
        subtitle.text = "Run paused until selection"
        subtitle.fontSize = 15
        subtitle.fontColor = .lightGray
        subtitle.position = CGPoint(x: 0, y: 76)
        panel.addChild(subtitle)
        let offeredPerks = PerkType.allCases.shuffled().prefix(3)
        for (i, perk) in offeredPerks.enumerated() {
            let option = makePerkOption(perk: perk)
            option.position = CGPoint(x: 0, y: 24 - CGFloat(i) * 66)
            panel.addChild(option)
        }
        gameCamera.addChild(overlay)
    }

    func makePerkOption(perk: PerkType) -> SKNode {
        let optionNode = SKNode()
        optionNode.name = "perkOption_\(perk.rawValue)"
        let button = SKShapeNode(rectOf: CGSize(width: 300, height: 52), cornerRadius: 10)
        button.fillColor = SKColor(white: 0.2, alpha: 1.0)
        button.strokeColor = SKColor(white: 0.95, alpha: 1.0)
        button.lineWidth = 1.5
        optionNode.addChild(button)
        let title = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        title.text = perkTitle(for: perk)
        title.fontSize = 18
        title.fontColor = .white
        title.verticalAlignmentMode = .center
        optionNode.addChild(title)
        return optionNode
    }

    func perkTitle(for perk: PerkType) -> String {
        switch perk {
        case .speed:    return "Speed +15%"
        case .damage:   return "Damage +1"
        case .fireRate: return "Fire Rate +20%"
        }
    }

    func applyPerk(_ perk: PerkType) {
        switch perk {
        case .speed:    playerMoveSpeed *= 1.15
        case .damage:   bulletDamage += 1
        case .fireRate:
            autoFireInterval = max(0.15, autoFireInterval * 0.8)
            if action(forKey: autoFireActionKey) != nil {
                removeAction(forKey: autoFireActionKey)
                startAutoFire()
            }
        }
    }

    func removePerkMenuOverlay() { gameCamera.childNode(withName: perkOverlayName)?.removeFromParent() }

    func perkType(from nodeName: String) -> PerkType? {
        PerkType(rawValue: nodeName.replacingOccurrences(of: "perkOption_", with: ""))
    }

    // MARK: - Combate Automático
    func startAutoFire() {
        let fire = SKAction.run { [weak self] in self?.fireAtNearestEnemy() }
        let wait = SKAction.wait(forDuration: autoFireInterval)
        run(SKAction.repeatForever(SKAction.sequence([fire, wait])), withKey: autoFireActionKey)
    }

    func fireAtNearestEnemy() {
        guard gameState == .running, let target = nearestEnemy() else { return }
        let dx = target.position.x - player.position.x
        let dy = target.position.y - player.position.y
        let dist = sqrt(dx*dx + dy*dy)
        guard dist > 0 else { return }
        spawnBullet(direction: CGVector(dx: dx/dist, dy: dy/dist))
        run(SKAction.playSoundFileNamed("aBullet.wav", waitForCompletion: false))
    }

    func nearestEnemy() -> SKSpriteNode? {
        var nearest: SKSpriteNode?
        var shortest = CGFloat.greatestFiniteMagnitude
        enumerateChildNodes(withName: "enemy") { node, _ in
            guard let e = node as? SKSpriteNode else { return }
            let dx = e.position.x - self.player.position.x
            let dy = e.position.y - self.player.position.y
            let d2 = dx*dx + dy*dy
            if d2 < shortest { shortest = d2; nearest = e }
        }
        return nearest
    }

    func spawnBullet(direction: CGVector) {
        let bullet = SKSpriteNode(imageNamed: "sBullet")
        bullet.texture?.filteringMode = .nearest
        bullet.size = CGSize(width: 16, height: 16)
        bullet.name = "bullet"
        bullet.position = player.position
        bullet.zPosition = 50
        let angle = atan2(direction.dy, direction.dx)
        bullet.zRotation = angle - .pi/2

        bullet.physicsBody = SKPhysicsBody(circleOfRadius: 6)
        bullet.physicsBody?.affectedByGravity = false
        bullet.physicsBody?.allowsRotation    = false
        bullet.physicsBody?.categoryBitMask   = PhysicsCategory.bullet
        bullet.physicsBody?.collisionBitMask  = PhysicsCategory.none
        bullet.physicsBody?.contactTestBitMask = PhysicsCategory.enemy
        bullet.physicsBody?.usesPreciseCollisionDetection = true

        addChild(bullet)
        let move    = SKAction.move(by: CGVector(dx: direction.dx * bulletRange, dy: direction.dy * bulletRange),
                                    duration: TimeInterval(bulletRange / bulletSpeed))
        bullet.run(SKAction.sequence([move, .removeFromParent()]))
    }

    // MARK: - Loop Principal
    override func update(_ currentTime: TimeInterval) {
        guard gameState == .running else { return }

        if runStartTime == nil { runStartTime = currentTime }
        if let t = runStartTime { currentRunSurvivalTime = max(0, currentTime - t) }

        gameCamera.position = player.position

        let moving = joystick.velocity != .zero
        if moving != isPlayerMoving {
            isPlayerMoving = moving
            player.removeAction(forKey: "anim")
            let frames = moving ? playerRunFrames : playerIdleFrames
            let tpf: TimeInterval = moving ? 0.1 : 0.15
            player.run(SKAction.repeatForever(SKAction.animate(with: frames, timePerFrame: tpf)), withKey: "anim")
        }

        if joystick.velocity != .zero {
            player.position.x += joystick.velocity.x * playerMoveSpeed
            player.position.y += joystick.velocity.y * playerMoveSpeed
            // Flip sprite horizontally based on direction
            if joystick.velocity.x < -0.1 {
                player.xScale = -1
            } else if joystick.velocity.x > 0.1 {
                player.xScale = 1
            }
        }

        let enemySpeed: CGFloat = 2.0
        enumerateChildNodes(withName: "enemy") { node, _ in
            guard let e = node as? SKSpriteNode else { return }
            let dx = self.player.position.x - e.position.x
            let dy = self.player.position.y - e.position.y
            let angle = atan2(dy, dx)
            e.position.x += cos(angle) * enemySpeed
            e.position.y += sin(angle) * enemySpeed
            // Enemy faces direction of movement via xScale flip
            if dx > 0 { e.xScale = 1 } else if dx < 0 { e.xScale = -1 }
        }
    }

    // MARK: - Colisão
    func didBegin(_ contact: SKPhysicsContact) {
        guard gameState == .running else { return }
        let maskA = contact.bodyA.categoryBitMask
        let maskB = contact.bodyB.categoryBitMask
        let mask  = maskA | maskB

        if mask == (PhysicsCategory.player | PhysicsCategory.enemy) {
            triggerGameOver(); return
        }

        if mask == (PhysicsCategory.bullet | PhysicsCategory.enemy) {
            let enemyNode    = maskA == PhysicsCategory.enemy ? contact.bodyA.node : contact.bodyB.node
            let bulletNode   = maskA == PhysicsCategory.bullet ? contact.bodyA.node : contact.bodyB.node
            let enemyPos     = enemyNode?.position
            bulletNode?.removeFromParent()

            let currentHealth = enemyNode?.userData?["health"] as? Int ?? 1
            let remaining = max(0, currentHealth - bulletDamage)
            if remaining > 0 {
                enemyNode?.userData?["health"] = remaining
            } else {
                if let pos = enemyPos {
                    showEnemyDeath(at: pos)
                    run(SKAction.playSoundFileNamed("aDeath.wav", waitForCompletion: false))
                    spawnDataBit(at: pos)
                }
                enemyNode?.removeFromParent()
            }
        }

        if mask == (PhysicsCategory.player | PhysicsCategory.dataBit) {
            let dataBitNode = maskA == PhysicsCategory.dataBit ? contact.bodyA.node : contact.bodyB.node
            collectDataBit(dataBitNode)
        }
    }

    func showEnemyDeath(at position: CGPoint) {
        let dead = SKSpriteNode(imageNamed: "sEnemyDead")
        dead.texture?.filteringMode = .nearest
        dead.size = CGSize(width: 40, height: 40)
        dead.position = position
        dead.zPosition = 11
        addChild(dead)
        let fade = SKAction.fadeOut(withDuration: 0.4)
        dead.run(SKAction.sequence([fade, .removeFromParent()]))
    }

    // MARK: - Estado de Jogo
    func triggerGameOver() {
        guard gameState == .running else { return }
        gameState = .gameOver
        finalizeRunProgress()
        removeAction(forKey: "enemySpawner")
        removeAction(forKey: autoFireActionKey)
        joystick.removeFromParent()
        enumerateChildNodes(withName: "enemy") { node, _ in
            node.removeAllActions()
            node.physicsBody?.velocity = .zero
        }
        showGameOverOverlay()
    }

    func showGameOverOverlay() {
        let overlay = SKNode()
        overlay.name = gameOverOverlayName
        overlay.zPosition = 300
        let panel = SKShapeNode(rectOf: CGSize(width: 320, height: 180), cornerRadius: 16)
        panel.fillColor = SKColor(white: 0.08, alpha: 0.92)
        panel.strokeColor = .white
        panel.lineWidth = 2
        overlay.addChild(panel)
        let title = SKLabelNode(fontNamed: "AvenirNext-Bold")
        title.text = "GAME OVER"
        title.fontSize = 34
        title.fontColor = .white
        title.position = CGPoint(x: 0, y: 25)
        overlay.addChild(title)
        let subtitle = SKLabelNode(fontNamed: "AvenirNext-Regular")
        subtitle.text = "Sobreviveu: \(formattedTime(currentRunSurvivalTime)) | Recorde: \(formattedTime(bestSurvivalTime))"
        subtitle.fontSize = 18
        subtitle.fontColor = .lightGray
        subtitle.position = CGPoint(x: 0, y: -22)
        overlay.addChild(subtitle)
        let progressLabel = SKLabelNode(fontNamed: "AvenirNext-Regular")
        progressLabel.text = "Data Bits: \(totalDataBitsBank) | Melhor nível: \(highestLevelReached)"
        progressLabel.fontSize = 15
        progressLabel.fontColor = .systemTeal
        progressLabel.position = CGPoint(x: 0, y: -50)
        overlay.addChild(progressLabel)
        gameCamera.addChild(overlay)
    }

    func restartRun() {
        let scene = GameScene(fileNamed: "GameScene") ?? GameScene(size: size)
        scene.scaleMode = scaleMode
        view?.presentScene(scene, transition: SKTransition.crossFade(withDuration: 0.25))
    }

    func showPauseMenu() {
        removePauseMenu()
        let overlay = SKNode()
        overlay.name = "pauseOverlay"
        overlay.zPosition = 320
        let dim = SKShapeNode(rectOf: CGSize(width: size.width, height: size.height))
        dim.fillColor = SKColor(white: 0.0, alpha: 0.75)
        dim.strokeColor = .clear
        overlay.addChild(dim)
        let panel = SKShapeNode(rectOf: CGSize(width: 280, height: 220), cornerRadius: 20)
        panel.fillColor = SKColor(white: 0.1, alpha: 0.95)
        panel.strokeColor = SKColor(white: 0.9, alpha: 1.0)
        panel.lineWidth = 2
        overlay.addChild(panel)
        let title = SKLabelNode(fontNamed: "AvenirNext-Bold")
        title.text = "Paused"
        title.fontSize = 30
        title.fontColor = .white
        title.position = CGPoint(x: 0, y: 70)
        panel.addChild(title)
        let resumeButton = SKShapeNode(rectOf: CGSize(width: 210, height: 48), cornerRadius: 12)
        resumeButton.fillColor = SKColor(white: 0.2, alpha: 1.0)
        resumeButton.strokeColor = SKColor(white: 0.95, alpha: 1.0)
        resumeButton.lineWidth = 2
        resumeButton.position = CGPoint(x: 0, y: 10)
        resumeButton.name = "resumeButton"
        panel.addChild(resumeButton)
        let resumeLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        resumeLabel.text = "Resume"
        resumeLabel.fontSize = 22
        resumeLabel.fontColor = .white
        resumeLabel.verticalAlignmentMode = .center
        resumeLabel.isUserInteractionEnabled = false
        resumeButton.addChild(resumeLabel)
        let exitButton = SKShapeNode(rectOf: CGSize(width: 210, height: 48), cornerRadius: 12)
        exitButton.fillColor = SKColor(red: 0.55, green: 0.05, blue: 0.05, alpha: 1.0)
        exitButton.strokeColor = SKColor(white: 0.8, alpha: 1.0)
        exitButton.lineWidth = 2
        exitButton.position = CGPoint(x: 0, y: -50)
        exitButton.name = "exitButton"
        panel.addChild(exitButton)
        let exitLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        exitLabel.text = "Exit"
        exitLabel.fontSize = 22
        exitLabel.fontColor = .white
        exitLabel.verticalAlignmentMode = .center
        exitLabel.isUserInteractionEnabled = false
        exitButton.addChild(exitLabel)
        gameCamera.addChild(overlay)
    }

    func removePauseMenu() { gameCamera.childNode(withName: "pauseOverlay")?.removeFromParent() }

    func cameraNodes(at touch: UITouch) -> [SKNode] {
        gameCamera.nodes(at: touch.location(in: gameCamera))
    }

    func firstMatchingNodeName(in nodes: [SKNode], where predicate: (String) -> Bool) -> String? {
        for node in nodes {
            var cur: SKNode? = node
            while let c = cur {
                if let n = c.name, predicate(n) { return n }
                cur = c.parent
            }
        }
        return nil
    }

    // MARK: - Input
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let tappedNodes = cameraNodes(at: touch)

        if gameState == .paused {
            if firstMatchingNodeName(in: tappedNodes, where: { $0 == "resumeButton" }) != nil {
                joystick.reset(animated: false); isPaused = false; removePauseMenu(); gameState = .running; return
            }
            if firstMatchingNodeName(in: tappedNodes, where: { $0 == "exitButton" }) != nil {
                isPaused = false; removePauseMenu()
                let menu = MainMenuScene(size: size); menu.scaleMode = scaleMode
                view?.presentScene(menu, transition: SKTransition.fade(with: SKColor(red:0.04,green:0.06,blue:0.10,alpha:1), duration: 0.4))
                return
            }
        }

        if gameState == .gameOver { restartRun(); return }

        if gameState == .perkSelection {
            if let name = firstMatchingNodeName(in: tappedNodes, where: { $0.hasPrefix("perkOption_") }),
               let perk = perkType(from: name) {
                pendingPerkSelections = max(0, pendingPerkSelections - 1)
                applyPerk(perk)
                resumeAfterPerkSelection()
            }
            return
        }

        if firstMatchingNodeName(in: tappedNodes, where: { $0 == "pauseButton" }) != nil {
            joystick.reset(animated: false); gameState = .paused; isPaused = true; showPauseMenu(); return
        }

        super.touchesBegan(touches, with: event)
    }

    // MARK: - Persistência
    func loadPersistentProgress() {
        let d = UserDefaults.standard
        let s = d.double(forKey: PersistenceKey.bestSurvivalTime)
        bestSurvivalTime    = s.isFinite ? max(0, s) : 0
        totalDataBitsBank   = max(0, d.integer(forKey: PersistenceKey.totalDataBitsBank))
        highestLevelReached = max(1, d.integer(forKey: PersistenceKey.highestLevelReached))
    }

    func finalizeRunProgress() {
        bestSurvivalTime    = max(bestSurvivalTime, currentRunSurvivalTime)
        totalDataBitsBank  += max(0, currentRunDataBitsCollected)
        highestLevelReached = max(highestLevelReached, currentLevel)
        persistProgress()
        refreshBestTimeUI()
    }

    func persistProgress() {
        let d = UserDefaults.standard
        d.set(bestSurvivalTime,    forKey: PersistenceKey.bestSurvivalTime)
        d.set(totalDataBitsBank,   forKey: PersistenceKey.totalDataBitsBank)
        d.set(highestLevelReached, forKey: PersistenceKey.highestLevelReached)
    }

    func refreshBestTimeUI() {
        guard bestTimeLabel != nil else { return }
        bestTimeLabel.text = "Best Survival: \(formattedTime(bestSurvivalTime))"
    }

    func formattedTime(_ time: TimeInterval) -> String {
        let t = Int(max(0, time.rounded(.down)))
        return String(format: "%02d:%02d", t/60, t%60)
    }
}
