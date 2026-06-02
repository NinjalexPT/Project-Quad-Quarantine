import SpriteKit
import GameplayKit
import AVFoundation

// MARK: - Physics Categories
struct PhysicsCategory {
    static let none:        UInt32 = 0
    static let player:      UInt32 = 0b1
    static let enemy:       UInt32 = 0b10
    static let bullet:      UInt32 = 0b100
    static let dataBit:     UInt32 = 0b1000
    static let powerUp:     UInt32 = 0b10000
    static let scrapBit:    UInt32 = 0b100000
    static let enemyBullet: UInt32 = 0b1000000
}

class GameScene: SKScene, SKPhysicsContactDelegate {

    // MARK: - Persistence Keys
    private enum PersistenceKey {
        static let bestSurvivalTime    = "bestSurvivalTime"
        static let totalDataBitsBank   = "totalDataBitsBank"
        static let highestLevelReached = "highestLevelReached"
        static let bestMaxHealth       = "bestMaxHealth"
        static let bestHealthRegen     = "bestHealthRegen"
    }

    // MARK: - Enums
    enum GameState { case running, perkSelection, gameOver, paused }

    enum PerkType: String, CaseIterable {
        case speed          = "Speed"
        case damage         = "Damage"
        case fireRate       = "Fire Rate"
        case maxHealth      = "Max Health"
        case healthRegen    = "Health Regen"
        case magnetStrength = "Magnet Strength"
    }

    // MARK: - Nodes
    var player: SKSpriteNode!
    var joystick: Joystick!
    let gameCamera = SKCameraNode()

    // MARK: - Enemy Types
    enum EnemyType: String {
        case normal  = "enemy"
        case tank    = "enemyTank"
        case ranged  = "enemyRanged"
    }

    // MARK: - Map Boundaries
    private let mapHalfWidth:  CGFloat = 1792   // 28 * 128 / 2
    private let mapHalfHeight: CGFloat = 1792

    // MARK: - Game State
    var gameState: GameState = .running
    private let gameOverOverlayName = "gameOverOverlay"
    private let perkOverlayName     = "perkOverlay"
    private let soundMenuName       = "soundMenu"
    private let autoFireActionKey   = "autoFireAction"

    // MARK: - Sound Slider State
    private var activeSliderId: String? = nil   // "musicSlider" | "effectsSlider"

    // MARK: - Player Combat Stats
    private var playerMoveSpeed:    CGFloat      = 5.0
    private var bulletDamage:       Int          = 1
    private var autoFireInterval:   TimeInterval = 0.45
    private let bulletSpeed:        CGFloat      = 520
    private let bulletRange:        CGFloat      = 900

    // MARK: - Health
    private var playerMaxHealth:        Int     = 100
    private var playerCurrentHealth:    Int     = 100
    private var healthRegenPerSecond:   CGFloat = 0.0
    private var healthRegenAccumulator: CGFloat = 0.0
    private var lastDamageTime:         TimeInterval = -99
    private let damageCooldown:         TimeInterval = 0.6
    private let damagePerHit:           Int     = 20

    // MARK: - Magnet
    private var magnetActive:   Bool    = false
    private var magnetRadius:   CGFloat = 0
    private var magnetSpawned:  Bool    = false
    private let magnetSpawnTime: TimeInterval = 40

    // MARK: - XP / Level
    private let dataBitPickupRadius: CGFloat = 8
    private let xpPerDataBit:        Int     = 1
    private let baseXPToLevelUp:     Int     = 5
    private let xpStepPerLevel:      Int     = 3
    private var currentLevel:        Int     = 1
    private var currentXP:           Int     = 0
    private var xpToNextLevel:       Int     = 5
    private var pendingPerkSelections: Int   = 0

    // MARK: - Difficulty
    private var currentSpawnInterval: TimeInterval = 1.5
    private var difficultyTier:       Int          = 0
    private var lastRangedFireTime:   [ObjectIdentifier: TimeInterval] = [:]
    private let rangedFireInterval:   TimeInterval = 2.8
    private let rangedFireRange:      CGFloat      = 420
    private let rangedStopDistance:   CGFloat      = 320

    // MARK: - Persistence / Run tracking
    private var bestSurvivalTime:            TimeInterval = 0
    private var totalDataBitsBank:           Int          = 0
    private var highestLevelReached:         Int          = 1
    private var bestMaxHealth:               Int          = 100
    private var bestHealthRegen:             Int          = 0
    private var currentRunSurvivalTime:      TimeInterval = 0
    private var currentRunDataBitsCollected: Int          = 0
    private var runStartTime:                TimeInterval?
    private var currentRunBitsCollected: Int    = 0
    private let baseScrapBitDropChance:  Double = 0.25

    // MARK: - HUD Nodes
    private var xpBarFillNode: SKShapeNode!
    private var levelLabel:    SKLabelNode!
    private var xpLabel:       SKLabelNode!
    private var bestTimeLabel: SKLabelNode!
    private var pauseButton:   SKShapeNode!
    private var healthBarFill: SKShapeNode!
    private var healthLabel:   SKLabelNode!

    // MARK: - Animation
    private var playerIdleFrames: [SKTexture] = []
    private var playerRunFrames:  [SKTexture] = []
    private var isPlayerMoving = false

    // MARK: - Frame Helper
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

    // MARK: - Lifecycle
    override func didMove(to view: SKView) {
        loadPersistentProgress()
        applyPermanentUpgrades()
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = SKColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1.0)
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
        // Fundo: tile de Fundo.png (1024x1024) em grelha para cobrir o mapa inteiro
        let tileSize: CGFloat = 128   // cada tile — ajusta se ficares a gostar de outro tamanho
        let count     = 28            // 28 * 128 = 3584px em cada eixo
        let half      = CGFloat(count) * tileSize / 2.0

        for col in 0..<count {
            for row in 0..<count {
                let tile = SKSpriteNode(imageNamed: "Fundo")
                tile.size     = CGSize(width: tileSize, height: tileSize)
                tile.texture?.filteringMode = .nearest
                tile.position = CGPoint(
                    x: CGFloat(col) * tileSize - half + tileSize / 2,
                    y: CGFloat(row) * tileSize - half + tileSize / 2
                )
                tile.zPosition = -10
                addChild(tile)
            }
        }

        // Mapa central por cima do fundo
        let mapNode = SKSpriteNode(imageNamed: "sMap")
        mapNode.size = CGSize(width: 320, height: 320)
        mapNode.texture?.filteringMode = .nearest
        mapNode.position   = .zero
        mapNode.zPosition  = -9
        addChild(mapNode)

        // Arbustos placeholder
        spawnBushPlaceholders()
    }

    private func spawnBushPlaceholders() {
        // Posicoes espalhadas pelo mapa - substituir por sprites reais na Fase 3
        let positions: [(CGFloat, CGFloat)] = [
            (180, 120), (-200, 150), (300, -180), (-320, -100),
            (450,  80), (-440, 200), (240, -300), (-180, -350),
            (520,-240), (-500,-180), (160,  420), (-300,  380),
            (380, 300), (-420,-320), (100, -460), (-160,  460),
            (600, 160), (-580,  80), (340, -500), (-360,  500),
            (680, -80), (-660,-240), (200,  560), (-220, -560),
            (480, 480), (-500,-500), (560, -360), (-540,  380),
            (760, 320), (-740, 120)
        ]
        for (x, y) in positions {
            // Corpo principal do arbusto
            let bush = SKShapeNode(ellipseOf: CGSize(width: 38, height: 28))
            bush.fillColor  = SKColor(red: 0.14, green: 0.42, blue: 0.14, alpha: 0.92)
            bush.strokeColor = SKColor(red: 0.07, green: 0.25, blue: 0.07, alpha: 1.0)
            bush.lineWidth  = 1.5
            bush.position   = CGPoint(x: x, y: y)
            bush.zPosition  = 5
            bush.name       = "bush"

            // Topo secundario para dar volume
            let top = SKShapeNode(ellipseOf: CGSize(width: 26, height: 22))
            top.fillColor  = SKColor(red: 0.20, green: 0.55, blue: 0.20, alpha: 0.85)
            top.strokeColor = .clear
            top.position   = CGPoint(x: 5, y: 9)
            top.zPosition  = 1
            bush.addChild(top)

            addChild(bush)
        }
    }

    // MARK: - Player Setup
    func setupPlayer() {
        playerIdleFrames = GameScene.makeFrames(from: "sPlayerIdle_strip4", frameCount: 4)
        playerRunFrames  = GameScene.makeFrames(from: "sPlayerRun_strip7",  frameCount: 7)

        player = SKSpriteNode(texture: playerIdleFrames[0])
        player.size     = CGSize(width: 40, height: 40)
        player.position = .zero
        player.zPosition = 10

        player.physicsBody = SKPhysicsBody(rectangleOf: player.size)
        player.physicsBody?.affectedByGravity  = false
        player.physicsBody?.allowsRotation     = false
        player.physicsBody?.categoryBitMask    = PhysicsCategory.player
        player.physicsBody?.collisionBitMask   = PhysicsCategory.none
        player.physicsBody?.contactTestBitMask =
            PhysicsCategory.enemy | PhysicsCategory.dataBit | PhysicsCategory.powerUp | PhysicsCategory.scrapBit | PhysicsCategory.enemyBullet
        player.physicsBody?.usesPreciseCollisionDetection = true
        addChild(player)

        // Gun — orbita o player; posição inicial à direita
        let gun = SKSpriteNode(imageNamed: "sGun")
        gun.texture?.filteringMode = .nearest
        gun.size       = CGSize(width: 40, height: 20)
        gun.position   = CGPoint(x: 34, y: 0)   // raio de orbita inicial
        gun.zRotation  = 0
        gun.zPosition  = 1
        gun.name       = "gun"
        player.addChild(gun)

        playPlayerIdle()
    }

    private func playPlayerIdle() {
        guard !isPlayerMoving else { return }
        if player.action(forKey: "anim") == nil {
            let anim = SKAction.animate(with: playerIdleFrames, timePerFrame: 0.15)
            player.run(SKAction.repeatForever(anim), withKey: "anim")
        }
    }

    // MARK: - Joystick
    func setupJoystick() {
        joystick = Joystick(radius: 60)
        joystick.position = CGPoint(x: -size.width / 2 + 140, y: -size.height / 2 + 100)
        joystick.zPosition = 100
        gameCamera.addChild(joystick)
    }

    // MARK: - HUD
    func setupHUD() {
        let barW:  CGFloat = 240
        let barH:  CGFloat = 16
        let hudY = size.height / 2 - 56

        // --- XP Bar ---
        let xpBg = SKShapeNode(rectOf: CGSize(width: barW, height: barH), cornerRadius: 8)
        xpBg.fillColor = SKColor(white: 0.2, alpha: 0.9)
        xpBg.strokeColor = SKColor(white: 0.85, alpha: 1.0)
        xpBg.lineWidth = 2
        xpBg.position  = CGPoint(x: 0, y: hudY)
        xpBg.zPosition = 140
        gameCamera.addChild(xpBg)

        xpBarFillNode = SKShapeNode(rectOf: CGSize(width: barW - 4, height: barH - 4), cornerRadius: 6)
        xpBarFillNode.fillColor  = .systemGreen
        xpBarFillNode.strokeColor = .clear
        xpBarFillNode.position  = CGPoint(x: 0, y: hudY)
        xpBarFillNode.zPosition = 141
        gameCamera.addChild(xpBarFillNode)

        // --- Health Bar ---
        let hpBg = SKShapeNode(rectOf: CGSize(width: barW, height: barH), cornerRadius: 8)
        hpBg.fillColor  = SKColor(white: 0.2, alpha: 0.9)
        hpBg.strokeColor = SKColor(white: 0.85, alpha: 1.0)
        hpBg.lineWidth  = 2
        hpBg.position   = CGPoint(x: 0, y: hudY - 22)
        hpBg.zPosition  = 140
        gameCamera.addChild(hpBg)

        healthBarFill = SKShapeNode(rectOf: CGSize(width: barW - 4, height: barH - 4), cornerRadius: 6)
        healthBarFill.fillColor  = .systemRed
        healthBarFill.strokeColor = .clear
        healthBarFill.position  = CGPoint(x: 0, y: hudY - 22)
        healthBarFill.zPosition = 141
        gameCamera.addChild(healthBarFill)

        // --- Labels ---
        levelLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        levelLabel.fontSize = 16
        levelLabel.fontColor = .white
        levelLabel.horizontalAlignmentMode = .left
        levelLabel.position  = CGPoint(x: -barW / 2, y: hudY + 18)
        levelLabel.zPosition = 142
        gameCamera.addChild(levelLabel)

        xpLabel = SKLabelNode(fontNamed: "AvenirNext-Regular")
        xpLabel.fontSize = 14
        xpLabel.fontColor = .white
        xpLabel.horizontalAlignmentMode = .right
        xpLabel.position  = CGPoint(x: barW / 2, y: hudY + 18)
        xpLabel.zPosition = 142
        gameCamera.addChild(xpLabel)

        healthLabel = SKLabelNode(fontNamed: "AvenirNext-Regular")
        healthLabel.fontSize = 13
        healthLabel.fontColor = SKColor(red: 1, green: 0.45, blue: 0.45, alpha: 1)
        healthLabel.horizontalAlignmentMode = .left
        healthLabel.position  = CGPoint(x: -barW / 2, y: hudY - 28)
        healthLabel.zPosition = 142
        gameCamera.addChild(healthLabel)

        bestTimeLabel = SKLabelNode(fontNamed: "AvenirNext-Regular")
        bestTimeLabel.fontSize = 14
        bestTimeLabel.fontColor = .systemYellow
        bestTimeLabel.horizontalAlignmentMode = .center
        bestTimeLabel.position  = CGPoint(x: 0, y: hudY + 38)
        bestTimeLabel.zPosition = 142
        gameCamera.addChild(bestTimeLabel)

        // --- Pause Button ---
        pauseButton = SKShapeNode(rectOf: CGSize(width: 44, height: 44), cornerRadius: 8)
        pauseButton.fillColor  = SKColor(white: 0.15, alpha: 0.85)
        pauseButton.strokeColor = SKColor(white: 0.9, alpha: 1.0)
        pauseButton.lineWidth  = 2
        pauseButton.position   = CGPoint(x: size.width / 2 - 38, y: hudY + 38)
        pauseButton.zPosition  = 150
        pauseButton.name       = "pauseButton"
        let pauseSymbol = SKLabelNode(fontNamed: "AvenirNext-Bold")
        pauseSymbol.text = "❚❚"
        pauseSymbol.fontSize  = 26
        pauseSymbol.fontColor = .white
        pauseSymbol.verticalAlignmentMode   = .center
        pauseSymbol.horizontalAlignmentMode = .center
        pauseSymbol.isUserInteractionEnabled = false
        pauseButton.addChild(pauseSymbol)
        gameCamera.addChild(pauseButton)

        let bitsHUD = SKLabelNode(fontNamed: "AvenirNext-Bold")
        bitsHUD.name = "bitsHUDLabel"
        bitsHUD.fontSize = 14
        bitsHUD.fontColor = SKColor(red: 1.0, green: 0.82, blue: 0.0, alpha: 1.0)
        bitsHUD.horizontalAlignmentMode = .right
        bitsHUD.position  = CGPoint(x: size.width / 2 - 48, y: hudY - 4)
        bitsHUD.zPosition = 142
        gameCamera.addChild(bitsHUD)

        updateXPUI()
        updateHealthUI()
        updateBitsHUD()
    }

    // MARK: - Enemy Spawner
    func startEnemySpawner() {
        removeAction(forKey: "enemySpawner")
        let spawn = SKAction.run { [weak self] in self?.spawnEnemy() }
        let wait  = SKAction.wait(forDuration: currentSpawnInterval)
        run(SKAction.repeatForever(SKAction.sequence([spawn, wait])), withKey: "enemySpawner")
    }

    func spawnEnemy() {
        // Decide tipo baseado no tier: normal sempre disponível, tank a partir tier 1, ranged a partir tier 2
        let roll = Double.random(in: 0..<1)
        let type: EnemyType
        if difficultyTier >= 5 && roll < 0.20 {
            type = .ranged
        } else if difficultyTier >= 3 && roll < 0.35 {
            type = .tank
        } else {
            type = .normal
        }
        spawnEnemyOfType(type)
    }

    private func spawnEnemyOfType(_ type: EnemyType) {
        let enemy = SKSpriteNode()
        enemy.name      = type.rawValue
        enemy.zPosition = 9
        enemy.userData  = NSMutableDictionary()

        switch type {
        case .normal:
            let frames = GameScene.makeFrames(from: "sEnemy_strip7", frameCount: 7)
            enemy.texture = frames[0]
            enemy.size    = CGSize(width: 40, height: 40)
            let anim = SKAction.animate(with: frames, timePerFrame: 0.10)
            enemy.run(SKAction.repeatForever(anim), withKey: "walkAnim")
            let hp = max(1, Int(pow(1.6, Double(difficultyTier))))
            enemy.userData?["health"] = hp

        case .tank:
            // Grande, lento, muito mais vida — usa o mesmo sprite escalado com tint vermelho-escuro
            let frames = GameScene.makeFrames(from: "sEnemy_strip7", frameCount: 7)
            enemy.texture = frames[0]
            enemy.size    = CGSize(width: 70, height: 70)
            enemy.color      = SKColor(red: 0.85, green: 0.20, blue: 0.20, alpha: 1.0)
            enemy.colorBlendFactor = 0.55
            let anim = SKAction.animate(with: frames, timePerFrame: 0.18)
            enemy.run(SKAction.repeatForever(anim), withKey: "walkAnim")
            let hp = max(4, Int(pow(1.6, Double(difficultyTier))) * 4)
            enemy.userData?["health"] = hp
            enemy.userData?["isTank"] = true

        case .ranged:
            // Mantém distância e dispara projéteis lentos
            let frames = GameScene.makeFrames(from: "sEnemy_strip7", frameCount: 7)
            enemy.texture = frames[0]
            enemy.size    = CGSize(width: 38, height: 38)
            enemy.color      = SKColor(red: 0.30, green: 0.30, blue: 1.00, alpha: 1.0)
            enemy.colorBlendFactor = 0.65
            let anim = SKAction.animate(with: frames, timePerFrame: 0.12)
            enemy.run(SKAction.repeatForever(anim), withKey: "walkAnim")
            let hp = max(1, Int(pow(1.6, Double(difficultyTier))) * 2)
            enemy.userData?["health"]   = hp
            enemy.userData?["isRanged"] = true
        }

        enemy.physicsBody = SKPhysicsBody(rectangleOf: enemy.size)
        enemy.physicsBody?.affectedByGravity  = false
        enemy.physicsBody?.allowsRotation     = false
        enemy.physicsBody?.categoryBitMask    = PhysicsCategory.enemy
        enemy.physicsBody?.collisionBitMask   = PhysicsCategory.none
        enemy.physicsBody?.contactTestBitMask = PhysicsCategory.player | PhysicsCategory.bullet
        enemy.physicsBody?.usesPreciseCollisionDetection = true

        // Spawn fora do ecrã
        let margin: CGFloat = 80
        let camX = gameCamera.position.x
        let camY = gameCamera.position.y
        let hw = size.width  / 2
        let hh = size.height / 2
        switch Int.random(in: 0...3) {
        case 0: enemy.position = CGPoint(x: CGFloat.random(in: camX-hw...camX+hw), y: camY+hh+margin)
        case 1: enemy.position = CGPoint(x: CGFloat.random(in: camX-hw...camX+hw), y: camY-hh-margin)
        case 2: enemy.position = CGPoint(x: camX-hw-margin, y: CGFloat.random(in: camY-hh...camY+hh))
        default: enemy.position = CGPoint(x: camX+hw+margin, y: CGFloat.random(in: camY-hh...camY+hh))
        }
        addChild(enemy)
    }

    // MARK: - Difficulty
    private func updateDifficulty() {
        let tier = Int(currentRunSurvivalTime / 30)   // novo tier a cada 30s
        guard tier > difficultyTier else { return }
        difficultyTier = tier
        // Intervalo diminui 15% por tier, minimo 0.25s
        currentSpawnInterval = max(0.25, 1.5 * pow(0.85, Double(difficultyTier)))
        startEnemySpawner()   // reinicia com novo intervalo
    }

    private func currentEnemySpeed() -> CGFloat {
        return min(7.0, 2.0 + CGFloat(difficultyTier) * 0.35)
    }

    // MARK: - Data Bits
    func spawnDataBit(at position: CGPoint) {
        let dataBit = SKShapeNode(circleOfRadius: dataBitPickupRadius)
        dataBit.name        = "dataBit"
        dataBit.fillColor   = .cyan
        dataBit.strokeColor = SKColor(white: 0.9, alpha: 1.0)
        dataBit.lineWidth   = 1.5
        dataBit.position    = position
        dataBit.zPosition   = 40
        dataBit.physicsBody = SKPhysicsBody(circleOfRadius: dataBitPickupRadius)
        dataBit.physicsBody?.isDynamic   = false
        dataBit.physicsBody?.affectedByGravity = false
        dataBit.physicsBody?.categoryBitMask   = PhysicsCategory.dataBit
        dataBit.physicsBody?.collisionBitMask  = PhysicsCategory.none
        dataBit.physicsBody?.contactTestBitMask = PhysicsCategory.player
        dataBit.physicsBody?.usesPreciseCollisionDetection = true
        addChild(dataBit)
    }

    func collectDataBit(_ node: SKNode?) {
        guard let node else { return }
        node.removeFromParent()
        currentRunDataBitsCollected += xpPerDataBit
        gainXP(xpPerDataBit)
    }

    // MARK: - Magnet Power-Up
    func spawnMagnetPickup() {
        magnetSpawned = true
        let angle  = CGFloat.random(in: 0...(.pi * 2))
        let dist:  CGFloat = 200
        let pos = CGPoint(x: player.position.x + cos(angle) * dist,
                          y: player.position.y + sin(angle) * dist)

        let magnet = SKShapeNode(circleOfRadius: 18)
        magnet.name       = "magnetPickup"
        magnet.fillColor  = SKColor(red: 1.0, green: 0.82, blue: 0.0, alpha: 1.0)
        magnet.strokeColor = SKColor(red: 1.0, green: 0.55, blue: 0.0, alpha: 1.0)
        magnet.lineWidth  = 3
        magnet.position   = pos
        magnet.zPosition  = 45

        let icon = SKLabelNode(fontNamed: "AvenirNext-Bold")
        icon.text = "M"
        icon.fontSize = 20
        icon.fontColor = .black
        icon.verticalAlignmentMode   = .center
        icon.horizontalAlignmentMode = .center
        magnet.addChild(icon)

        let pulse = SKAction.repeatForever(SKAction.sequence([
            SKAction.scale(to: 1.25, duration: 0.45),
            SKAction.scale(to: 1.00, duration: 0.45)
        ]))
        magnet.run(pulse)

        magnet.physicsBody = SKPhysicsBody(circleOfRadius: 18)
        magnet.physicsBody?.isDynamic   = false
        magnet.physicsBody?.affectedByGravity = false
        magnet.physicsBody?.categoryBitMask   = PhysicsCategory.powerUp
        magnet.physicsBody?.collisionBitMask  = PhysicsCategory.none
        magnet.physicsBody?.contactTestBitMask = PhysicsCategory.player
        addChild(magnet)
    }

    func collectMagnet() {
        magnetActive = true
        magnetRadius = 150
        childNode(withName: "magnetPickup")?.removeFromParent()

        let feedback = SKLabelNode(fontNamed: "AvenirNext-Bold")
        feedback.text     = "🧲 MAGNET!"
        feedback.fontSize = 26
        feedback.fontColor = SKColor(red: 1.0, green: 0.82, blue: 0.0, alpha: 1.0)
        feedback.position = CGPoint(x: 0, y: size.height / 2 - 130)
        feedback.zPosition = 200
        feedback.alpha    = 0
        gameCamera.addChild(feedback)
        feedback.run(SKAction.sequence([
            SKAction.group([SKAction.scale(to: 1.15, duration: 0.12),
                            SKAction.fadeIn(withDuration: 0.12)]),
            SKAction.wait(forDuration: 0.8),
            SKAction.group([SKAction.scale(to: 1.0,  duration: 0.2),
                            SKAction.fadeOut(withDuration: 0.2)]),
            .removeFromParent()
        ]))

        // Anel indicativo do raio
        let ring = SKShapeNode(circleOfRadius: magnetRadius)
        ring.strokeColor = SKColor(red: 1.0, green: 0.82, blue: 0.0, alpha: 0.6)
        ring.fillColor   = SKColor(red: 1.0, green: 0.82, blue: 0.0, alpha: 0.05)
        ring.lineWidth   = 2
        ring.zPosition   = 8
        ring.name        = "magnetRingIndicator"
        player.addChild(ring)
        ring.run(SKAction.sequence([
            SKAction.wait(forDuration: 1.5),
            SKAction.fadeOut(withDuration: 0.5),
            .removeFromParent()
        ]))
    }

    // MARK: - XP / Level Up
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
        let norm = max(0, min(1, CGFloat(currentXP) / CGFloat(max(1, xpToNextLevel))))
        xpBarFillNode.xScale = norm
        levelLabel.text = "LEVEL \(currentLevel)"
        xpLabel.text    = "\(currentXP)/\(xpToNextLevel) XP"
    }

    func updateHealthUI() {
        let ratio = max(0, min(1, CGFloat(playerCurrentHealth) / CGFloat(max(1, playerMaxHealth))))
        healthBarFill.xScale = ratio
        healthLabel.text = "♥ \(playerCurrentHealth)/\(playerMaxHealth)"
        switch ratio {
        case ..<0.3:  healthBarFill.fillColor = .systemRed
        case ..<0.6:  healthBarFill.fillColor = .systemOrange
        default:      healthBarFill.fillColor = SKColor(red: 0.2, green: 0.85, blue: 0.35, alpha: 1.0)
        }
    }

    func showLevelUpFeedback() {
        let lbl = SKLabelNode(fontNamed: "AvenirNext-Bold")
        lbl.text      = "LEVEL UP!"
        lbl.fontSize  = 28
        lbl.fontColor = .systemYellow
        lbl.position  = CGPoint(x: 0, y: size.height / 2 - 120)
        lbl.zPosition = 200
        lbl.alpha     = 0
        gameCamera.addChild(lbl)
        lbl.run(SKAction.sequence([
            SKAction.group([SKAction.scale(to: 1.15, duration: 0.12),
                            SKAction.fadeIn(withDuration: 0.12)]),
            SKAction.wait(forDuration: 0.35),
            SKAction.group([SKAction.scale(to: 1.0,  duration: 0.18),
                            SKAction.fadeOut(withDuration: 0.18)]),
            .removeFromParent()
        ]))
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
        gameState = .running
        if pendingPerkSelections > 0 { pauseForPerkSelection() }
    }

    func showPerkMenuOverlay() {
        removePerkMenuOverlay()
        let overlay = SKNode()
        overlay.name      = perkOverlayName
        overlay.zPosition = 320

        let dim = SKShapeNode(rectOf: CGSize(width: size.width, height: size.height))
        dim.fillColor  = SKColor(white: 0.0, alpha: 0.75)
        dim.strokeColor = .clear
        overlay.addChild(dim)

        let panel = SKShapeNode(rectOf: CGSize(width: 360, height: 310), cornerRadius: 20)
        panel.fillColor  = SKColor(white: 0.1, alpha: 0.95)
        panel.strokeColor = SKColor(white: 0.9, alpha: 1.0)
        panel.lineWidth  = 2
        panel.position   = CGPoint(x: 0, y: 16)
        overlay.addChild(panel)

        let title = SKLabelNode(fontNamed: "AvenirNext-Bold")
        title.text     = "Choose a Perk"
        title.fontSize = 30
        title.fontColor = .white
        title.position = CGPoint(x: 0, y: 120)
        panel.addChild(title)

        let subtitle = SKLabelNode(fontNamed: "AvenirNext-Regular")
        subtitle.text     = "Run paused until selection"
        subtitle.fontSize = 15
        subtitle.fontColor = .lightGray
        subtitle.position = CGPoint(x: 0, y: 92)
        panel.addChild(subtitle)

        // Pool de perks disponíveis
        var pool: [PerkType] = [.speed, .damage, .fireRate, .maxHealth, .healthRegen]
        if magnetActive { pool.append(.magnetStrength) }
        let offered = pool.shuffled().prefix(3)

        for (i, perk) in offered.enumerated() {
            let option = makePerkOption(perk: perk)
            option.position = CGPoint(x: 0, y: 40 - CGFloat(i) * 70)
            panel.addChild(option)
        }

        gameCamera.addChild(overlay)
    }

    func makePerkOption(perk: PerkType) -> SKNode {
        let node = SKNode()
        node.name = "perkOption_\(perk.rawValue)"

        let btn = SKShapeNode(rectOf: CGSize(width: 310, height: 56), cornerRadius: 10)
        btn.fillColor  = SKColor(white: 0.2, alpha: 1.0)
        btn.strokeColor = SKColor(white: 0.95, alpha: 1.0)
        btn.lineWidth  = 1.5
        node.addChild(btn)

        let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        label.text     = perkTitle(for: perk)
        label.fontSize = 18
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        node.addChild(label)

        return node
    }

    func perkTitle(for perk: PerkType) -> String {
        switch perk {
        case .speed:          return "⚡ Speed +15%"
        case .damage:         return "🗡 Damage +1"
        case .fireRate:       return "🔥 Fire Rate +20%"
        case .maxHealth:      return "♥ Max Health +20"
        case .healthRegen:    return "💚 Health Regen +2/s"
        case .magnetStrength: return "🧲 Magnet Range +50"
        }
    }

    func applyPerk(_ perk: PerkType) {
        switch perk {
        case .speed:
            playerMoveSpeed *= 1.15
        case .damage:
            bulletDamage += 1
        case .fireRate:
            autoFireInterval = max(0.15, autoFireInterval * 0.8)
            removeAction(forKey: autoFireActionKey)
            startAutoFire()
        case .maxHealth:
            playerMaxHealth      += 20
            playerCurrentHealth   = min(playerMaxHealth, playerCurrentHealth + 20)
            updateHealthUI()
        case .healthRegen:
            healthRegenPerSecond += 2.0
        case .magnetStrength:
            magnetRadius += 50
        }
    }

    func removePerkMenuOverlay() {
        gameCamera.childNode(withName: perkOverlayName)?.removeFromParent()
    }

    func perkType(from nodeName: String) -> PerkType? {
        PerkType(rawValue: nodeName.replacingOccurrences(of: "perkOption_", with: ""))
    }

    // MARK: - Auto Fire + Gun Rotation
    func startAutoFire() {
        let fire = SKAction.run { [weak self] in self?.fireAtNearestEnemy() }
        let wait = SKAction.wait(forDuration: autoFireInterval)
        run(SKAction.repeatForever(SKAction.sequence([fire, wait])), withKey: autoFireActionKey)
    }

    func fireAtNearestEnemy() {
        guard gameState == .running, let target = nearestEnemy() else { return }
        let dx = target.position.x - player.position.x
        let dy = target.position.y - player.position.y
        let dist = sqrt(dx * dx + dy * dy)
        guard dist > 0 else { return }

        let dir = CGVector(dx: dx / dist, dy: dy / dist)
        spawnBullet(direction: dir)
        SoundManager.shared.playEffect(named: "aBullet.wav", on: self)

        // Arma orbita o player: posicao + rotacao calculadas a partir do angulo
        if let gun = player.childNode(withName: "gun") as? SKSpriteNode {
            let worldAngle   = atan2(dy, dx)
            let orbitRadius: CGFloat = 34
            gun.position  = CGPoint(x: cos(worldAngle) * orbitRadius,
                                    y: sin(worldAngle) * orbitRadius)
            gun.zRotation = worldAngle   // aponta na direcao do disparo
            gun.xScale    = 1            // sem flip — a posicao trata da direcao
        }
    }

    func nearestEnemy() -> SKSpriteNode? {
        var nearest: SKSpriteNode?
        var shortest = CGFloat.greatestFiniteMagnitude
        for typeName in [EnemyType.normal.rawValue, EnemyType.tank.rawValue, EnemyType.ranged.rawValue] {
            enumerateChildNodes(withName: typeName) { node, _ in
                guard let e = node as? SKSpriteNode else { return }
                let dx = e.position.x - self.player.position.x
                let dy = e.position.y - self.player.position.y
                let d2 = dx * dx + dy * dy
                if d2 < shortest { shortest = d2; nearest = e }
            }
        }
        return nearest
    }

    func spawnBullet(direction: CGVector) {
        let bullet = SKSpriteNode(imageNamed: "sBullet")
        bullet.texture?.filteringMode = .nearest
        bullet.size     = CGSize(width: 16, height: 16)
        bullet.name     = "bullet"
        bullet.position = player.position
        bullet.zPosition = 50
        bullet.zRotation = atan2(direction.dy, direction.dx) - .pi / 2

        bullet.physicsBody = SKPhysicsBody(circleOfRadius: 6)
        bullet.physicsBody?.affectedByGravity = false
        bullet.physicsBody?.allowsRotation    = false
        bullet.physicsBody?.categoryBitMask   = PhysicsCategory.bullet
        bullet.physicsBody?.collisionBitMask  = PhysicsCategory.none
        bullet.physicsBody?.contactTestBitMask = PhysicsCategory.enemy
        bullet.physicsBody?.usesPreciseCollisionDetection = true
        addChild(bullet)

        let move = SKAction.move(by: CGVector(dx: direction.dx * bulletRange,
                                              dy: direction.dy * bulletRange),
                                  duration: TimeInterval(bulletRange / bulletSpeed))
        bullet.run(SKAction.sequence([move, .removeFromParent()]))
    }

    // MARK: - Main Update Loop
    override func update(_ currentTime: TimeInterval) {
        guard gameState == .running else { return }

        if runStartTime == nil { runStartTime = currentTime }
        if let t = runStartTime { currentRunSurvivalTime = max(0, currentTime - t) }

        // Dificuldade
        updateDifficulty()

        // Spawn do íman (uma unica vez apos magnetSpawnTime segundos)
        if !magnetSpawned && currentRunSurvivalTime >= magnetSpawnTime {
            spawnMagnetPickup()
        }

        // Health Regen (aprox. 60fps)
        if healthRegenPerSecond > 0 && playerCurrentHealth < playerMaxHealth {
            healthRegenAccumulator += healthRegenPerSecond / 60.0
            let healed = Int(healthRegenAccumulator)
            if healed >= 1 {
                healthRegenAccumulator -= CGFloat(healed)
                playerCurrentHealth = min(playerMaxHealth, playerCurrentHealth + healed)
                updateHealthUI()
            }
        }

        // Camera segue o player com clamping aos limites do mapa
        let camHalfW = size.width  / 2
        let camHalfH = size.height / 2
        let clampedX = max(-mapHalfWidth  + camHalfW, min(mapHalfWidth  - camHalfW, player.position.x))
        let clampedY = max(-mapHalfHeight + camHalfH, min(mapHalfHeight - camHalfH, player.position.y))
        gameCamera.position = CGPoint(x: clampedX, y: clampedY)

        // Animacao do player
        let moving = joystick.velocity != .zero
        if moving != isPlayerMoving {
            isPlayerMoving = moving
            player.removeAction(forKey: "anim")
            let frames = moving ? playerRunFrames : playerIdleFrames
            let tpf: TimeInterval = moving ? 0.1 : 0.15
            player.run(SKAction.repeatForever(
                SKAction.animate(with: frames, timePerFrame: tpf)), withKey: "anim")
        }

        if joystick.velocity != .zero {
            player.position.x += joystick.velocity.x * playerMoveSpeed
            player.position.y += joystick.velocity.y * playerMoveSpeed
            if      joystick.velocity.x < -0.1 { player.xScale = -1 }
            else if joystick.velocity.x >  0.1 { player.xScale =  1 }
        }

        // Clamp player within map bounds
        let playerHalf: CGFloat = 20
        player.position.x = max(-mapHalfWidth  + playerHalf, min(mapHalfWidth  - playerHalf, player.position.x))
        player.position.y = max(-mapHalfHeight + playerHalf, min(mapHalfHeight - playerHalf, player.position.y))

        // Inimigos normais movem-se em direção ao player
        let eSpeed = currentEnemySpeed()
        enumerateChildNodes(withName: EnemyType.normal.rawValue) { node, _ in
            guard let e = node as? SKSpriteNode else { return }
            let dx = self.player.position.x - e.position.x
            let dy = self.player.position.y - e.position.y
            let angle = atan2(dy, dx)
            e.position.x += cos(angle) * eSpeed
            e.position.y += sin(angle) * eSpeed
            if dx > 0 { e.xScale = 1 } else if dx < 0 { e.xScale = -1 }
        }

        // Tank: lento, move-se sempre em direção ao player
        let tankSpeed = max(0.8, eSpeed * 0.45)
        enumerateChildNodes(withName: EnemyType.tank.rawValue) { node, _ in
            guard let e = node as? SKSpriteNode else { return }
            let dx = self.player.position.x - e.position.x
            let dy = self.player.position.y - e.position.y
            let angle = atan2(dy, dx)
            e.position.x += cos(angle) * tankSpeed
            e.position.y += sin(angle) * tankSpeed
            if dx > 0 { e.xScale = 1 } else if dx < 0 { e.xScale = -1 }
        }

        // Ranged: mantém distância ideal, dispara projéteis
        let rangedSpeed = max(1.2, eSpeed * 0.65)
        enumerateChildNodes(withName: EnemyType.ranged.rawValue) { node, _ in
            guard let e = node as? SKSpriteNode else { return }
            let dx   = self.player.position.x - e.position.x
            let dy   = self.player.position.y - e.position.y
            let dist = sqrt(dx * dx + dy * dy)
            let angle = atan2(dy, dx)

            if dist > self.rangedStopDistance + 20 {
                // Aproxima até à distância ideal
                e.position.x += cos(angle) * rangedSpeed
                e.position.y += sin(angle) * rangedSpeed
            } else if dist < self.rangedStopDistance - 20 {
                // Recua se o player se aproximar demasiado
                e.position.x -= cos(angle) * rangedSpeed
                e.position.y -= sin(angle) * rangedSpeed
            }
            if dx > 0 { e.xScale = 1 } else if dx < 0 { e.xScale = -1 }

            // Disparo com intervalo
            let id = ObjectIdentifier(e)
            let lastFire = self.lastRangedFireTime[id] ?? -99
            if currentTime - lastFire >= self.rangedFireInterval && dist <= self.rangedFireRange {
                self.lastRangedFireTime[id] = currentTime
                let dir = CGVector(dx: dx / dist, dy: dy / dist)
                self.spawnEnemyBullet(from: e.position, direction: dir)
            }
        }

        // Ima: atrai data bits dentro do raio
        if magnetActive && magnetRadius > 0 {
            enumerateChildNodes(withName: "dataBit") { node, _ in
                let dx   = self.player.position.x - node.position.x
                let dy   = self.player.position.y - node.position.y
                let dist = sqrt(dx * dx + dy * dy)
                guard dist < self.magnetRadius && dist > 1 else { return }
                let speed: CGFloat = 4.5
                node.position.x += (dx / dist) * speed
                node.position.y += (dy / dist) * speed
            }
        }
    }

    // MARK: - Collision
    func didBegin(_ contact: SKPhysicsContact) {
        guard gameState == .running else { return }
        let maskA = contact.bodyA.categoryBitMask
        let maskB = contact.bodyB.categoryBitMask
        let mask  = maskA | maskB

        // Player tocado por inimigo -> dano com cooldown
        if mask == (PhysicsCategory.player | PhysicsCategory.enemy) {
            let now = CACurrentMediaTime()
            guard now - lastDamageTime >= damageCooldown else { return }
            lastDamageTime = now
            // Tank faz mais dano
            let enemyNode = maskA == PhysicsCategory.enemy ? contact.bodyA.node : contact.bodyB.node
            let dmg = (enemyNode?.userData?["isTank"] as? Bool == true) ? damagePerHit * 2 : damagePerHit
            takeDamage(dmg)
            return
        }

        // Projétil inimigo atinge player
        if mask == (PhysicsCategory.player | PhysicsCategory.enemyBullet) {
            let bulletNode = maskA == PhysicsCategory.enemyBullet ? contact.bodyA.node : contact.bodyB.node
            bulletNode?.removeFromParent()
            let now = CACurrentMediaTime()
            guard now - lastDamageTime >= 0.3 else { return }
            lastDamageTime = now
            takeDamage(damagePerHit)
            return
        }

        // Bala atinge inimigo
        if mask == (PhysicsCategory.bullet | PhysicsCategory.enemy) {
            let enemyNode  = maskA == PhysicsCategory.enemy  ? contact.bodyA.node : contact.bodyB.node
            let bulletNode = maskA == PhysicsCategory.bullet ? contact.bodyA.node : contact.bodyB.node
            let enemyPos   = enemyNode?.position
            bulletNode?.removeFromParent()

            let hp        = enemyNode?.userData?["health"] as? Int ?? 1
            let remaining = max(0, hp - bulletDamage)
            if remaining > 0 {
                enemyNode?.userData?["health"] = remaining
                // Flash de dano no tank
                if enemyNode?.userData?["isTank"] as? Bool == true {
                    enemyNode?.run(SKAction.sequence([
                        SKAction.colorize(with: .white, colorBlendFactor: 0.9, duration: 0.05),
                        SKAction.colorize(with: SKColor(red: 0.85, green: 0.20, blue: 0.20, alpha: 1.0), colorBlendFactor: 0.55, duration: 0.15)
                    ]))
                }
            } else {
                if let pos = enemyPos {
                    let isTank = enemyNode?.userData?["isTank"] as? Bool == true
                    showEnemyDeath(at: pos, big: isTank)
                    SoundManager.shared.playEffect(named: "aDeath.wav", on: self)
                    spawnDataBit(at: pos)
                    if isTank { spawnDataBit(at: CGPoint(x: pos.x + 10, y: pos.y + 10)) }
                    tryDropScrapBit(at: pos)
                    if isTank { tryDropScrapBit(at: pos) }
                    // Limpar timer do ranged se necessário
                    if let node = enemyNode { lastRangedFireTime.removeValue(forKey: ObjectIdentifier(node)) }
                }
                enemyNode?.removeFromParent()
            }
        }

        // Player apanha data bit
        if mask == (PhysicsCategory.player | PhysicsCategory.dataBit) {
            let dataBitNode = maskA == PhysicsCategory.dataBit ? contact.bodyA.node : contact.bodyB.node
            collectDataBit(dataBitNode)
        }

        // Player apanha scrap bit
        if mask == (PhysicsCategory.player | PhysicsCategory.scrapBit) {
            let bitNode = maskA == PhysicsCategory.scrapBit ? contact.bodyA.node : contact.bodyB.node
            collectScrapBit(bitNode)
        }

        // Player apanha scrap bit (moeda da loja)
        if mask == (PhysicsCategory.player | PhysicsCategory.scrapBit) {
            let bitNode = maskA == PhysicsCategory.scrapBit ? contact.bodyA.node : contact.bodyB.node
            collectScrapBit(bitNode)
        }

        // Player apanha iman
        if mask == (PhysicsCategory.player | PhysicsCategory.powerUp) {
            collectMagnet()
        }
    }

    private func takeDamage(_ amount: Int) {
        playerCurrentHealth = max(0, playerCurrentHealth - amount)
        updateHealthUI()

        // Flash vermelho no player
        player.run(SKAction.sequence([
            SKAction.colorize(with: .red, colorBlendFactor: 0.85, duration: 0.06),
            SKAction.colorize(with: .white, colorBlendFactor: 0.0, duration: 0.22)
        ]))

        if playerCurrentHealth <= 0 { triggerGameOver() }
    }

    func showEnemyDeath(at position: CGPoint, big: Bool = false) {
        let dead = SKSpriteNode(imageNamed: "sEnemyDead")
        dead.texture?.filteringMode = .nearest
        dead.size     = big ? CGSize(width: 70, height: 70) : CGSize(width: 40, height: 40)
        dead.position = position
        dead.zPosition = 11
        if big { dead.color = SKColor(red: 0.85, green: 0.20, blue: 0.20, alpha: 1.0); dead.colorBlendFactor = 0.55 }
        addChild(dead)
        dead.run(SKAction.sequence([SKAction.fadeOut(withDuration: big ? 0.6 : 0.4), .removeFromParent()]))
    }

    // MARK: - Game Over
    func triggerGameOver() {
        guard gameState == .running else { return }
        gameState = .gameOver
        finalizeRunProgress()
        removeAction(forKey: "enemySpawner")
        removeAction(forKey: autoFireActionKey)
        joystick.removeFromParent()
        for typeName in [EnemyType.normal.rawValue, EnemyType.tank.rawValue, EnemyType.ranged.rawValue] {
            enumerateChildNodes(withName: typeName) { node, _ in
                node.removeAllActions()
                node.physicsBody?.velocity = .zero
            }
        }
        enumerateChildNodes(withName: "enemyBulletNode") { node, _ in node.removeFromParent() }
        showGameOverOverlay()
    }

    func showGameOverOverlay() {
        let overlay = SKNode()
        overlay.name      = gameOverOverlayName
        overlay.zPosition = 300

        let panel = SKShapeNode(rectOf: CGSize(width: 340, height: 310), cornerRadius: 16)
        panel.fillColor  = SKColor(white: 0.08, alpha: 0.93)
        panel.strokeColor = .white
        panel.lineWidth  = 2
        overlay.addChild(panel)

        let title = SKLabelNode(fontNamed: "AvenirNext-Bold")
        title.text     = "GAME OVER"
        title.fontSize = 34
        title.fontColor = .white
        title.position = CGPoint(x: 0, y: 120)
        overlay.addChild(title)

        let timeLabel = SKLabelNode(fontNamed: "AvenirNext-Regular")
        timeLabel.text     = "Sobreviveu: \(formattedTime(currentRunSurvivalTime))  |  Recorde: \(formattedTime(bestSurvivalTime))"
        timeLabel.fontSize = 15
        timeLabel.fontColor = .lightGray
        timeLabel.position = CGPoint(x: 0, y: 76)
        overlay.addChild(timeLabel)

        let progressLabel = SKLabelNode(fontNamed: "AvenirNext-Regular")
        progressLabel.text     = "Data Bits: \(totalDataBitsBank)  |  Melhor nivel: \(highestLevelReached)"
        progressLabel.fontSize = 14
        progressLabel.fontColor = .systemTeal
        progressLabel.position = CGPoint(x: 0, y: 50)
        overlay.addChild(progressLabel)

        let hpLabel = SKLabelNode(fontNamed: "AvenirNext-Regular")
        hpLabel.text     = "♥ Max HP: \(playerMaxHealth)  |  Regen: \(Int(healthRegenPerSecond))/s"
        hpLabel.fontSize = 13
        hpLabel.fontColor = SKColor(red: 1, green: 0.5, blue: 0.5, alpha: 1)
        hpLabel.position = CGPoint(x: 0, y: 22)
        overlay.addChild(hpLabel)

        let magnetLabel = SKLabelNode(fontNamed: "AvenirNext-Regular")
        magnetLabel.text     = magnetActive ? "🧲 Iman ativo  |  Raio: \(Int(magnetRadius))px" : "🧲 Iman: nao recolhido"
        magnetLabel.fontSize = 13
        magnetLabel.fontColor = SKColor(red: 1.0, green: 0.82, blue: 0.0, alpha: 1.0)
        magnetLabel.position = CGPoint(x: 0, y: -4)
        overlay.addChild(magnetLabel)

        // ── Botão Recomeçar ──
        let restartBtn = SKShapeNode(rectOf: CGSize(width: 280, height: 48), cornerRadius: 12)
        restartBtn.fillColor   = SKColor(red: 0.10, green: 0.45, blue: 0.10, alpha: 1.0)
        restartBtn.strokeColor = SKColor(red: 0.30, green: 0.85, blue: 0.30, alpha: 1.0)
        restartBtn.lineWidth   = 1.5
        restartBtn.position    = CGPoint(x: 0, y: -60)
        restartBtn.name        = "gameOverRestart"
        overlay.addChild(restartBtn)

        let restartLbl = SKLabelNode(fontNamed: "AvenirNext-Bold")
        restartLbl.text     = "▶  RECOMEÇAR"
        restartLbl.fontSize = 19
        restartLbl.fontColor = .white
        restartLbl.verticalAlignmentMode   = .center
        restartLbl.horizontalAlignmentMode = .center
        restartLbl.isUserInteractionEnabled = false
        restartBtn.addChild(restartLbl)

        // ── Botão Menu Principal ──
        let menuBtn = SKShapeNode(rectOf: CGSize(width: 280, height: 48), cornerRadius: 12)
        menuBtn.fillColor   = SKColor(white: 0.15, alpha: 1.0)
        menuBtn.strokeColor = SKColor(white: 0.45, alpha: 1.0)
        menuBtn.lineWidth   = 1.5
        menuBtn.position    = CGPoint(x: 0, y: -120)
        menuBtn.name        = "gameOverMenu"
        overlay.addChild(menuBtn)

        let menuLbl = SKLabelNode(fontNamed: "AvenirNext-Bold")
        menuLbl.text     = "⌂  MENU PRINCIPAL"
        menuLbl.fontSize = 19
        menuLbl.fontColor = SKColor(red: 0.0, green: 0.95, blue: 0.75, alpha: 1.0)
        menuLbl.verticalAlignmentMode   = .center
        menuLbl.horizontalAlignmentMode = .center
        menuLbl.isUserInteractionEnabled = false
        menuBtn.addChild(menuLbl)

        gameCamera.addChild(overlay)
    }

    func restartRun() {
        let scene = GameScene(fileNamed: "GameScene") ?? GameScene(size: size)
        scene.scaleMode = scaleMode
        view?.presentScene(scene, transition: SKTransition.crossFade(withDuration: 0.25))
    }

    // MARK: - Pause Menu
    func showPauseMenu() {
        removePauseMenu()
        let overlay = SKNode()
        overlay.name      = "pauseOverlay"
        overlay.zPosition = 320

        let dim = SKShapeNode(rectOf: CGSize(width: size.width, height: size.height))
        dim.fillColor  = SKColor(white: 0.0, alpha: 0.75)
        dim.strokeColor = .clear
        overlay.addChild(dim)

        let panel = SKShapeNode(rectOf: CGSize(width: 280, height: 220), cornerRadius: 20)
        panel.fillColor  = SKColor(white: 0.1, alpha: 0.95)
        panel.strokeColor = SKColor(white: 0.9, alpha: 1.0)
        panel.lineWidth  = 2
        overlay.addChild(panel)

        let title = SKLabelNode(fontNamed: "AvenirNext-Bold")
        title.text     = "Paused"
        title.fontSize = 30
        title.fontColor = .white
        title.position = CGPoint(x: 0, y: 70)
        panel.addChild(title)

        for (name, label, color, y) in [
            ("resumeButton", "Resume",
             SKColor(white: 0.2, alpha: 1.0), CGFloat(10)),
            ("exitButton",   "Exit",
             SKColor(red: 0.55, green: 0.05, blue: 0.05, alpha: 1.0), CGFloat(-50))
        ] {
            let btn = SKShapeNode(rectOf: CGSize(width: 210, height: 48), cornerRadius: 12)
            btn.fillColor  = color
            btn.strokeColor = SKColor(white: 0.9, alpha: 1.0)
            btn.lineWidth  = 2
            btn.position   = CGPoint(x: 0, y: y)
            btn.name       = name
            panel.addChild(btn)
            let lbl = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
            lbl.text     = label
            lbl.fontSize = 22
            lbl.fontColor = .white
            lbl.verticalAlignmentMode   = .center
            lbl.isUserInteractionEnabled = false
            btn.addChild(lbl)
        }

        // Sound toggle button
        let soundBtn = SKShapeNode(rectOf: CGSize(width: 44, height: 44), cornerRadius: 10)
        soundBtn.fillColor   = SKColor(white: 0.15, alpha: 0.9)
        soundBtn.strokeColor = SKColor(white: 0.35, alpha: 1.0)
        soundBtn.lineWidth   = 1.5
        soundBtn.position    = CGPoint(x: size.width / 2 - 36, y: size.height / 2 - 36)
        soundBtn.zPosition   = 330
        soundBtn.name        = "pauseSoundButton"
        let soundIcon = SKLabelNode(fontNamed: "AvenirNext-Regular")
        soundIcon.text     = SoundManager.shared.isMuted ? "\u{1F507}" : "\u{1F50A}"
        soundIcon.fontSize = 22
        soundIcon.verticalAlignmentMode   = .center
        soundIcon.horizontalAlignmentMode = .center
        soundIcon.isUserInteractionEnabled = false
        soundIcon.name = "pauseSoundIcon"
        soundBtn.addChild(soundIcon)
        overlay.addChild(soundBtn)

        gameCamera.addChild(overlay)
    }

    func removePauseMenu() { gameCamera.childNode(withName: "pauseOverlay")?.removeFromParent() }

    // MARK: - Input Helpers
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
        let tapped = cameraNodes(at: touch)

        if gameState == .paused {
            if firstMatchingNodeName(in: tapped, where: { $0 == "pauseSoundButton" || $0 == "pauseSoundIcon" }) != nil {
                if gameCamera.childNode(withName: soundMenuName) != nil {
                    hideSoundMenu()
                } else {
                    showSoundMenu()
                }
                return
            }
            // Sound menu interactions while paused
            if let name = firstMatchingNodeName(in: tapped, where: {
                $0 == "soundMenuClose" || $0 == "soundMenuMute" || $0 == "soundMenuBg" || $0 == "soundMenuBack"
            }) {
                if name == "soundMenuClose" || name == "soundMenuBg" || name == "soundMenuBack" {
                    hideSoundMenu(reopenPause: true)
                } else if name == "soundMenuMute" {
                    SoundManager.shared.isMuted.toggle()
                    hideSoundMenu(reopenPause: false)
                    showSoundMenu()
                }
                return
            }
            if let name = firstMatchingNodeName(in: tapped, where: { $0 == "musicSlider" || $0 == "effectsSlider" }) {
                activeSliderId = name
                let x = touch.location(in: gameCamera).x
                updateSlider(id: name, touchX: x)
                return
            }
            if firstMatchingNodeName(in: tapped, where: { $0 == "resumeButton" }) != nil {
                joystick.reset(animated: false); isPaused = false; removePauseMenu(); gameState = .running; return
            }
            if firstMatchingNodeName(in: tapped, where: { $0 == "exitButton" }) != nil {
                isPaused = false; removePauseMenu()
                let menu = MainMenuScene(size: size); menu.scaleMode = scaleMode
                view?.presentScene(menu, transition: SKTransition.fade(
                    with: SKColor(red: 0.04, green: 0.06, blue: 0.10, alpha: 1), duration: 0.4))
                return
            }
        }

        if gameState == .gameOver {
            let name = firstMatchingNodeName(in: tapped, where: {
                $0 == "gameOverRestart" || $0 == "gameOverMenu"
            })
            if name == "gameOverMenu" {
                let menu = MainMenuScene(size: size)
                menu.scaleMode = scaleMode
                view?.presentScene(menu, transition: SKTransition.fade(
                    with: SKColor(red: 0.04, green: 0.06, blue: 0.10, alpha: 1), duration: 0.4))
            } else {
                // toca no botão Recomeçar OU em qualquer outro sítio
                restartRun()
            }
            return
        }

        if gameState == .perkSelection {
            if let name = firstMatchingNodeName(in: tapped, where: { $0.hasPrefix("perkOption_") }),
               let perk = perkType(from: name) {
                pendingPerkSelections = max(0, pendingPerkSelections - 1)
                applyPerk(perk)
                resumeAfterPerkSelection()
            }
            return
        }

        if firstMatchingNodeName(in: tapped, where: { $0 == "pauseButton" }) != nil {
            joystick.reset(animated: false); gameState = .paused; isPaused = true; showPauseMenu(); return
        }

        super.touchesBegan(touches, with: event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let id = activeSliderId else { return }
        let x = touch.location(in: gameCamera).x
        updateSlider(id: id, touchX: x)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeSliderId = nil
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeSliderId = nil
    }

    // MARK: - Persistence
    func loadPersistentProgress() {
        let d = UserDefaults.standard
        let s = d.double(forKey: PersistenceKey.bestSurvivalTime)
        bestSurvivalTime    = s.isFinite ? max(0, s) : 0
        totalDataBitsBank   = max(0, d.integer(forKey: PersistenceKey.totalDataBitsBank))
        highestLevelReached = max(1, d.integer(forKey: PersistenceKey.highestLevelReached))
        bestMaxHealth       = max(100, d.integer(forKey: PersistenceKey.bestMaxHealth))
        bestHealthRegen     = max(0,   d.integer(forKey: PersistenceKey.bestHealthRegen))
    }

    func finalizeRunProgress() {
        bestSurvivalTime    = max(bestSurvivalTime, currentRunSurvivalTime)
        totalDataBitsBank  += max(0, currentRunDataBitsCollected)
        highestLevelReached = max(highestLevelReached, currentLevel)
        bestMaxHealth       = max(bestMaxHealth, playerMaxHealth)
        bestHealthRegen     = max(bestHealthRegen, Int(healthRegenPerSecond))
        if currentRunBitsCollected > 0 {
            UpgradeManager.shared.bitsBank += currentRunBitsCollected
            currentRunBitsCollected = 0
        }
        persistProgress()
        refreshBestTimeUI()
    }

    func persistProgress() {
        let d = UserDefaults.standard
        d.set(bestSurvivalTime,    forKey: PersistenceKey.bestSurvivalTime)
        d.set(totalDataBitsBank,   forKey: PersistenceKey.totalDataBitsBank)
        d.set(highestLevelReached, forKey: PersistenceKey.highestLevelReached)
        d.set(bestMaxHealth,       forKey: PersistenceKey.bestMaxHealth)
        d.set(bestHealthRegen,     forKey: PersistenceKey.bestHealthRegen)
    }

    func refreshBestTimeUI() {
        guard bestTimeLabel != nil else { return }
        bestTimeLabel.text = "Best: \(formattedTime(bestSurvivalTime))"
    }

    func formattedTime(_ time: TimeInterval) -> String {
        let t = Int(max(0, time.rounded(.down)))
        return String(format: "%02d:%02d", t / 60, t % 60)
    }
    // MARK: - Permanent Upgrades
    private func applyPermanentUpgrades() {
        let mgr = UpgradeManager.shared
        playerMaxHealth      += mgr.bonusMaxHealth
        playerCurrentHealth   = playerMaxHealth
        bulletDamage         += mgr.bonusDamage
        autoFireInterval     *= mgr.fireRateMultiplier
        playerMoveSpeed      *= CGFloat(mgr.speedMultiplier)
        healthRegenPerSecond += mgr.bonusHealthRegen
    }

    // MARK: - Scrap Bits (moeda permanente)
    private func tryDropScrapBit(at position: CGPoint) {
        let chance = baseScrapBitDropChance + UpgradeManager.shared.extraBitDropChance
        guard Double.random(in: 0..<1) < chance else { return }
        let ox = CGFloat.random(in: -10...10)
        let oy = CGFloat.random(in: -10...10)
        spawnScrapBit(at: CGPoint(x: position.x + ox, y: position.y + oy))
    }

    private func spawnScrapBit(at position: CGPoint) {
        let r: CGFloat = 7
        let bit = SKShapeNode(path: hexagonPath(radius: r))
        bit.name        = "scrapBit"
        bit.fillColor   = SKColor(red: 1.0, green: 0.78, blue: 0.0, alpha: 1.0)
        bit.strokeColor = SKColor(red: 1.0, green: 0.55, blue: 0.0, alpha: 1.0)
        bit.lineWidth   = 1.5
        bit.position    = position
        bit.zPosition   = 41
        let pulse = SKAction.repeatForever(SKAction.sequence([
            SKAction.scale(to: 1.22, duration: 0.4),
            SKAction.scale(to: 1.00, duration: 0.4)
        ]))
        bit.run(pulse)
        bit.physicsBody = SKPhysicsBody(circleOfRadius: r)
        bit.physicsBody?.isDynamic          = false
        bit.physicsBody?.affectedByGravity  = false
        bit.physicsBody?.categoryBitMask    = PhysicsCategory.scrapBit
        bit.physicsBody?.collisionBitMask   = PhysicsCategory.none
        bit.physicsBody?.contactTestBitMask = PhysicsCategory.player
        bit.physicsBody?.usesPreciseCollisionDetection = true
        addChild(bit)
    }

    private func hexagonPath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        for i in 0..<6 {
            let angle = CGFloat(i) * .pi / 3 - .pi / 6
            let x = radius * cos(angle)
            let y = radius * sin(angle)
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else       { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        path.closeSubpath()
        return path
    }

    func collectScrapBit(_ node: SKNode?) {
        guard let node = node else { return }
        node.removeAllActions()
        node.run(SKAction.sequence([
            SKAction.scale(to: 1.6, duration: 0.08),
            SKAction.fadeOut(withDuration: 0.12),
            .removeFromParent()
        ]))
        currentRunBitsCollected += 1
        updateBitsHUD()
        let lbl = SKLabelNode(fontNamed: "AvenirNext-Bold")
        lbl.text      = "+1"
        lbl.fontSize  = 14
        lbl.fontColor = SKColor(red: 1.0, green: 0.82, blue: 0.0, alpha: 1.0)
        lbl.position  = CGPoint(x: node.position.x, y: node.position.y + 16)
        lbl.zPosition = 200
        addChild(lbl)
        lbl.run(SKAction.sequence([
            SKAction.group([
                SKAction.moveBy(x: 0, y: 24, duration: 0.45),
                SKAction.fadeOut(withDuration: 0.45)
            ]),
            .removeFromParent()
        ]))
    }

    func updateBitsHUD() {
        if let lbl = gameCamera.childNode(withName: "bitsHUDLabel") as? SKLabelNode {
            lbl.text = "Bits: \(currentRunBitsCollected)"
        }
    }


    // MARK: - Sound Menu
    func showSoundMenu() {
        gameCamera.childNode(withName: soundMenuName)?.removeFromParent()

        // Esconde o menu de pausa (volta quando fechar o som)
        gameCamera.childNode(withName: "pauseOverlay")?.isHidden = true

        let overlay = SKNode()
        overlay.name      = soundMenuName
        overlay.zPosition = 350

        // Dim de fundo
        let dim = SKShapeNode(rectOf: CGSize(width: size.width, height: size.height))
        dim.fillColor   = SKColor(white: 0.0, alpha: 0.65)
        dim.strokeColor = .clear
        overlay.addChild(dim)

        // Painel central
        let panelW: CGFloat = 320
        let panelH: CGFloat = 340
        let panel = SKShapeNode(rectOf: CGSize(width: panelW, height: panelH), cornerRadius: 20)
        panel.fillColor   = SKColor(white: 0.09, alpha: 0.97)
        panel.strokeColor = SKColor(white: 0.80, alpha: 1.0)
        panel.lineWidth   = 2
        panel.name        = "soundMenuPanel"
        overlay.addChild(panel)

        // Título
        let title = SKLabelNode(fontNamed: "AvenirNext-Bold")
        title.text      = "🔊  Sound"
        title.fontSize  = 22
        title.fontColor = .white
        title.position  = CGPoint(x: 0, y: 156)
        panel.addChild(title)

        // Linha separadora
        let sep = SKShapeNode(rectOf: CGSize(width: panelW - 40, height: 1))
        sep.fillColor   = SKColor(white: 0.30, alpha: 1.0)
        sep.strokeColor = .clear
        sep.position    = CGPoint(x: 0, y: 118)
        panel.addChild(sep)

        // Sliders
        panel.addChild(buildSliderRow(
            id: "musicSlider",
            icon: "🎵",
            label: "Music",
            value: SoundManager.shared.musicVolume,
            y: 72
        ))
        panel.addChild(buildSliderRow(
            id: "effectsSlider",
            icon: "💥",
            label: "Effects",
            value: SoundManager.shared.effectsVolume,
            y: 0
        ))

        // Botão Mute All
        let muteBtn = SKShapeNode(rectOf: CGSize(width: panelW - 60, height: 44), cornerRadius: 12)
        muteBtn.fillColor   = SoundManager.shared.isMuted
            ? SKColor(red: 0.55, green: 0.10, blue: 0.10, alpha: 1.0)
            : SKColor(white: 0.18, alpha: 1.0)
        muteBtn.strokeColor = SKColor(white: 0.45, alpha: 1.0)
        muteBtn.lineWidth   = 1.5
        muteBtn.position    = CGPoint(x: 0, y: -72)
        muteBtn.name        = "soundMenuMute"
        let muteLbl = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        muteLbl.text      = SoundManager.shared.isMuted ? "🔇  Unmute All" : "🔇  Mute All"
        muteLbl.fontSize  = 16
        muteLbl.fontColor = .white
        muteLbl.verticalAlignmentMode   = .center
        muteLbl.horizontalAlignmentMode = .center
        muteLbl.isUserInteractionEnabled = false
        muteBtn.addChild(muteLbl)
        panel.addChild(muteBtn)

        // Botão ← Back
        let backBtn = SKShapeNode(rectOf: CGSize(width: panelW - 60, height: 44), cornerRadius: 12)
        backBtn.fillColor   = SKColor(red: 0.06, green: 0.32, blue: 0.20, alpha: 1.0)
        backBtn.strokeColor = SKColor(red: 0.10, green: 0.70, blue: 0.45, alpha: 1.0)
        backBtn.lineWidth   = 1.5
        backBtn.position    = CGPoint(x: 0, y: -136)
        backBtn.name        = "soundMenuBack"
        let backLbl = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        backLbl.text      = "← Back"
        backLbl.fontSize  = 16
        backLbl.fontColor = .white
        backLbl.verticalAlignmentMode   = .center
        backLbl.horizontalAlignmentMode = .center
        backLbl.isUserInteractionEnabled = false
        backBtn.addChild(backLbl)
        panel.addChild(backBtn)

        gameCamera.addChild(overlay)
    }

    private func buildSliderRow(id: String, icon: String, label: String, value: Float, y: CGFloat) -> SKNode {
        let row = SKNode()
        row.position = CGPoint(x: 0, y: y)

        // Label
        let lbl = SKLabelNode(fontNamed: "AvenirNext-Regular")
        lbl.text     = "\(icon) \(label)"
        lbl.fontSize = 14
        lbl.fontColor = SKColor(white: 0.8, alpha: 1.0)
        lbl.horizontalAlignmentMode = .left
        lbl.verticalAlignmentMode   = .center
        lbl.position = CGPoint(x: -130, y: 0)
        row.addChild(lbl)

        // Track
        let trackW: CGFloat = 160
        let trackH: CGFloat = 6
        let track = SKShapeNode(rectOf: CGSize(width: trackW, height: trackH), cornerRadius: 3)
        track.fillColor   = SKColor(white: 0.3, alpha: 1.0)
        track.strokeColor = .clear
        track.position    = CGPoint(x: 20, y: 0)
        track.name        = "\(id)Track"
        row.addChild(track)

        // Fill
        let fillW = max(6, trackW * CGFloat(value))
        let fill = SKShapeNode(rectOf: CGSize(width: fillW, height: trackH), cornerRadius: 3)
        fill.fillColor   = SKColor(red: 0.20, green: 0.75, blue: 0.40, alpha: 1.0)
        fill.strokeColor = .clear
        fill.position    = CGPoint(x: 20 - trackW / 2 + fillW / 2, y: 0)
        fill.name        = "\(id)Fill"
        row.addChild(fill)

        // Thumb
        let thumb = SKShapeNode(circleOfRadius: 10)
        thumb.fillColor   = .white
        thumb.strokeColor = SKColor(white: 0.7, alpha: 1.0)
        thumb.lineWidth   = 1.5
        thumb.position    = CGPoint(x: 20 - trackW / 2 + trackW * CGFloat(value), y: 0)
        thumb.name        = id
        row.addChild(thumb)

        // Valor %
        let valLbl = SKLabelNode(fontNamed: "AvenirNext-Regular")
        valLbl.text     = "\(Int(value * 100))%"
        valLbl.fontSize = 12
        valLbl.fontColor = SKColor(white: 0.6, alpha: 1.0)
        valLbl.horizontalAlignmentMode = .left
        valLbl.verticalAlignmentMode   = .center
        valLbl.position = CGPoint(x: 106, y: 0)
        valLbl.name     = "\(id)ValLbl"
        row.addChild(valLbl)

        return row
    }

    func hideSoundMenu(reopenPause: Bool = true) {
        gameCamera.childNode(withName: soundMenuName)?.removeFromParent()
        activeSliderId = nil
        // Restaura o menu de pausa se estava visível
        if reopenPause {
            gameCamera.childNode(withName: "pauseOverlay")?.isHidden = false
        }
    }

    private func updateSlider(id: String, touchX: CGFloat) {
        guard let menu = gameCamera.childNode(withName: soundMenuName) else { return }
        // Find the row containing this slider
        guard let thumb = menu.childNode(withName: "//\(id)") else { return }
        guard let row   = thumb.parent else { return }

        let trackW: CGFloat = 160
        let trackOriginX: CGFloat = 20 - trackW / 2   // left edge of track in row coords
        let localX = row.convert(CGPoint(x: touchX, y: 0), from: gameCamera).x
        let t = max(0.0, min(1.0, (localX - trackOriginX) / trackW))

        // Move thumb
        thumb.position.x = trackOriginX + trackW * t

        // Resize fill
        if let fill = row.childNode(withName: "\(id)Fill") {
            let fillW = max(6, trackW * t)
            fill.removeFromParent()
            let newFill = SKShapeNode(rectOf: CGSize(width: fillW, height: 6), cornerRadius: 3)
            newFill.fillColor   = SKColor(red: 0.20, green: 0.75, blue: 0.40, alpha: 1.0)
            newFill.strokeColor = .clear
            newFill.position    = CGPoint(x: trackOriginX + fillW / 2, y: 0)
            newFill.name        = "\(id)Fill"
            row.addChild(newFill)
        }

        // Update label
        if let valLbl = row.childNode(withName: "\(id)ValLbl") as? SKLabelNode {
            valLbl.text = "\(Int(t * 100))%"
        }

        // Apply
        if id == "musicSlider"   { SoundManager.shared.musicVolume   = Float(t) }
        if id == "effectsSlider" { SoundManager.shared.effectsVolume = Float(t) }
    }



    // MARK: - Enemy Ranged Bullet
    private func spawnEnemyBullet(from position: CGPoint, direction: CGVector) {
        let bulletSpeed:  CGFloat      = 160
        let bulletRange:  CGFloat      = 520
        let bulletRadius: CGFloat      = 8

        let bullet = SKShapeNode(circleOfRadius: bulletRadius)
        bullet.name        = "enemyBulletNode"
        bullet.fillColor   = SKColor(red: 0.95, green: 0.45, blue: 0.10, alpha: 1.0)
        bullet.strokeColor = SKColor(red: 1.00, green: 0.70, blue: 0.20, alpha: 1.0)
        bullet.lineWidth   = 2
        bullet.position    = position
        bullet.zPosition   = 48

        // Glow interno
        let glow = SKShapeNode(circleOfRadius: bulletRadius * 0.55)
        glow.fillColor   = SKColor(white: 1.0, alpha: 0.85)
        glow.strokeColor = .clear
        bullet.addChild(glow)

        bullet.physicsBody = SKPhysicsBody(circleOfRadius: bulletRadius)
        bullet.physicsBody?.affectedByGravity  = false
        bullet.physicsBody?.allowsRotation     = false
        bullet.physicsBody?.isDynamic          = true
        bullet.physicsBody?.categoryBitMask    = PhysicsCategory.enemyBullet
        bullet.physicsBody?.collisionBitMask   = PhysicsCategory.none
        bullet.physicsBody?.contactTestBitMask = PhysicsCategory.player
        bullet.physicsBody?.usesPreciseCollisionDetection = true
        addChild(bullet)

        let move = SKAction.move(
            by: CGVector(dx: direction.dx * bulletRange, dy: direction.dy * bulletRange),
            duration: TimeInterval(bulletRange / bulletSpeed)
        )
        bullet.run(SKAction.sequence([move, .removeFromParent()]))
    }


}
