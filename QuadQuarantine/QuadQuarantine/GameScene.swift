import SpriteKit
import GameplayKit

// MARK: - Categorias de Física
struct PhysicsCategory {
    static let none: UInt32     = 0
    static let player: UInt32   = 0b1       // 1
    static let enemy: UInt32    = 0b10      // 2
    static let bullet: UInt32   = 0b100     // 4
    static let dataBit: UInt32  = 0b1000    // 8
}

class GameScene: SKScene, SKPhysicsContactDelegate {
    private enum PersistenceKey {
        static let bestSurvivalTime = "bestSurvivalTime"
        static let totalDataBitsBank = "totalDataBitsBank"
        static let highestLevelReached = "highestLevelReached"
    }
    
    enum GameState {
        case running
        case perkSelection
        case gameOver
    }
    
    enum PerkType: String, CaseIterable {
        case speed = "Speed"
        case damage = "Damage"
        case fireRate = "Fire Rate"
    }
    
    // MARK: - Propriedades
    var player: SKSpriteNode!
    var joystick: Joystick!
    let gameCamera = SKCameraNode()
    var gameState: GameState = .running
    private let gameOverOverlayName = "gameOverOverlay"
    private let perkOverlayName = "perkOverlay"
    private let autoFireActionKey = "autoFireAction"
    private var autoFireInterval: TimeInterval = 0.45
    private let bulletSpeed: CGFloat = 520
    private let bulletRange: CGFloat = 900
    private let dataBitPickupRadius: CGFloat = 8
    private let xpPerDataBit: Int = 1
    private let baseXPToLevelUp: Int = 5
    private let xpStepPerLevel: Int = 3
    private var currentLevel: Int = 1
    private var currentXP: Int = 0
    private var xpToNextLevel: Int = 5
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
    
    // MARK: - Ciclo de Vida
    override func didMove(to view: SKView) {
        loadPersistentProgress()
        
        // 1. Configurar a âncora e a câmara
        self.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        self.backgroundColor = SKColor.darkGray
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self
        
        addChild(gameCamera)
        self.camera = gameCamera
        
        // 2. Setup dos elementos
        setupPlayer()
        setupJoystick()
        setupHUD()
        startEnemySpawner()
        startAutoFire()
        refreshBestTimeUI()
    }
    
    // MARK: - Setup
    func setupPlayer() {
        player = SKSpriteNode(color: .systemBlue, size: CGSize(width: 40, height: 40))
        player.position = .zero
        
        player.physicsBody = SKPhysicsBody(rectangleOf: player.size)
        player.physicsBody?.affectedByGravity = false
        player.physicsBody?.allowsRotation = false
        player.physicsBody?.categoryBitMask = PhysicsCategory.player
        player.physicsBody?.collisionBitMask = PhysicsCategory.none
        player.physicsBody?.contactTestBitMask = PhysicsCategory.enemy | PhysicsCategory.dataBit
        player.physicsBody?.usesPreciseCollisionDetection = true
        
        addChild(player)
    }
    
    func setupJoystick() {
        joystick = Joystick(radius: 60)
        
        // Posicionamento relativo ao ecrã
        let marginX: CGFloat = 140
        let marginY: CGFloat = 100
        
        joystick.position = CGPoint(
            x: -size.width / 2 + marginX,
            y: -size.height / 2 + marginY
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
        
        updateXPUI()
    }
    
    // MARK: - Inimigos (Spawn baseado na Câmara)
    func startEnemySpawner() {
        let spawn = SKAction.run { [weak self] in
            self?.spawnEnemy()
        }
        let wait = SKAction.wait(forDuration: 1.5)
        let sequence = SKAction.sequence([spawn, wait])
        run(SKAction.repeatForever(sequence), withKey: "enemySpawner")
    }
    
    func spawnEnemy() {
        let enemy = SKSpriteNode(color: .systemRed, size: CGSize(width: 30, height: 30))
        enemy.name = "enemy"
        
        enemy.physicsBody = SKPhysicsBody(rectangleOf: enemy.size)
        enemy.physicsBody?.affectedByGravity = false
        enemy.physicsBody?.allowsRotation = false
        enemy.physicsBody?.categoryBitMask = PhysicsCategory.enemy
        enemy.physicsBody?.collisionBitMask = PhysicsCategory.none
        enemy.physicsBody?.contactTestBitMask = PhysicsCategory.player
        enemy.physicsBody?.usesPreciseCollisionDetection = true
        enemy.userData = NSMutableDictionary()
        enemy.userData?["health"] = 1
        
        // Calcula a posição de spawn baseada onde a câmara está no momento
        let randomEdge = Int.random(in: 0...3)
        let margin: CGFloat = 80
        
        let camX = gameCamera.position.x
        let camY = gameCamera.position.y
        let halfWidth = size.width / 2
        let halfHeight = size.height / 2
        
        switch randomEdge {
        case 0: // Cima
            enemy.position = CGPoint(x: CGFloat.random(in: camX - halfWidth...camX + halfWidth), y: camY + halfHeight + margin)
        case 1: // Baixo
            enemy.position = CGPoint(x: CGFloat.random(in: camX - halfWidth...camX + halfWidth), y: camY - halfHeight - margin)
        case 2: // Esquerda
            enemy.position = CGPoint(x: camX - halfWidth - margin, y: CGFloat.random(in: camY - halfHeight...camY + halfHeight))
        default: // Direita
            enemy.position = CGPoint(x: camX + halfWidth + margin, y: CGFloat.random(in: camY - halfHeight...camY + halfHeight))
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
        dataBit.physicsBody?.isDynamic = false
        dataBit.physicsBody?.affectedByGravity = false
        dataBit.physicsBody?.categoryBitMask = PhysicsCategory.dataBit
        dataBit.physicsBody?.collisionBitMask = PhysicsCategory.none
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
        
        if gameState == .running, pendingPerkSelections > 0 {
            pauseForPerkSelection()
        }
    }
    
    func updateXPUI() {
        let normalizedXP = max(0, min(1, CGFloat(currentXP) / CGFloat(max(1, xpToNextLevel))))
        xpBarFillNode.xScale = normalizedXP
        levelLabel.text = "LEVEL \(currentLevel)"
        xpLabel.text = "\(currentXP)/\(xpToNextLevel) XP"
    }
    
    func showLevelUpFeedback() {
        let levelUpLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
        levelUpLabel.text = "LEVEL UP!"
        levelUpLabel.fontSize = 28
        levelUpLabel.fontColor = .systemYellow
        levelUpLabel.position = CGPoint(x: 0, y: size.height / 2 - 120)
        levelUpLabel.zPosition = 200
        gameCamera.addChild(levelUpLabel)
        
        let popIn = SKAction.group([
            SKAction.scale(to: 1.15, duration: 0.12),
            SKAction.fadeIn(withDuration: 0.12)
        ])
        let hold = SKAction.wait(forDuration: 0.35)
        let fadeOut = SKAction.group([
            SKAction.scale(to: 1.0, duration: 0.18),
            SKAction.fadeOut(withDuration: 0.18)
        ])
        levelUpLabel.alpha = 0
        levelUpLabel.run(SKAction.sequence([popIn, hold, fadeOut, .removeFromParent()]))
    }
    
    // MARK: - Perk Menu
    func pauseForPerkSelection() {
        guard gameState == .running else { return }
        gameState = .perkSelection
        isPaused = true
        showPerkMenuOverlay()
    }
    
    func resumeAfterPerkSelection() {
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
        dim.position = .zero
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
        for (index, perk) in offeredPerks.enumerated() {
            let option = makePerkOption(perk: perk)
            option.position = CGPoint(x: 0, y: 24 - CGFloat(index) * 66)
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
        case .speed:
            return "Speed +15%"
        case .damage:
            return "Damage +1"
        case .fireRate:
            return "Fire Rate +20%"
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
            if action(forKey: autoFireActionKey) != nil {
                removeAction(forKey: autoFireActionKey)
                startAutoFire()
            }
        }
    }
    
    func removePerkMenuOverlay() {
        gameCamera.childNode(withName: perkOverlayName)?.removeFromParent()
    }
    
    func perkType(from nodeName: String) -> PerkType? {
        let rawValue = nodeName.replacingOccurrences(of: "perkOption_", with: "")
        return PerkType(rawValue: rawValue)
    }
    
    // MARK: - Combate Automático
    func startAutoFire() {
        let fire = SKAction.run { [weak self] in
            self?.fireAtNearestEnemy()
        }
        let wait = SKAction.wait(forDuration: autoFireInterval)
        let sequence = SKAction.sequence([fire, wait])
        run(SKAction.repeatForever(sequence), withKey: autoFireActionKey)
    }
    
    func fireAtNearestEnemy() {
        guard gameState == .running else { return }
        guard let target = nearestEnemy() else { return }
        
        let directionX = target.position.x - player.position.x
        let directionY = target.position.y - player.position.y
        let distance = sqrt(directionX * directionX + directionY * directionY)
        guard distance > 0 else { return }
        
        let normalizedDirection = CGVector(dx: directionX / distance, dy: directionY / distance)
        spawnBullet(direction: normalizedDirection)
    }
    
    func nearestEnemy() -> SKSpriteNode? {
        var nearest: SKSpriteNode?
        var shortestDistance = CGFloat.greatestFiniteMagnitude
        
        enumerateChildNodes(withName: "enemy") { node, _ in
            guard let enemy = node as? SKSpriteNode else { return }
            let dx = enemy.position.x - self.player.position.x
            let dy = enemy.position.y - self.player.position.y
            let distanceSquared = (dx * dx) + (dy * dy)
            
            if distanceSquared < shortestDistance {
                shortestDistance = distanceSquared
                nearest = enemy
            }
        }
        
        return nearest
    }
    
    func spawnBullet(direction: CGVector) {
        let bullet = SKShapeNode(circleOfRadius: 5)
        bullet.name = "bullet"
        bullet.fillColor = .systemYellow
        bullet.strokeColor = .clear
        bullet.position = player.position
        bullet.zPosition = 50
        
        bullet.physicsBody = SKPhysicsBody(circleOfRadius: 5)
        bullet.physicsBody?.affectedByGravity = false
        bullet.physicsBody?.allowsRotation = false
        bullet.physicsBody?.categoryBitMask = PhysicsCategory.bullet
        bullet.physicsBody?.collisionBitMask = PhysicsCategory.none
        bullet.physicsBody?.contactTestBitMask = PhysicsCategory.enemy
        bullet.physicsBody?.usesPreciseCollisionDetection = true
        
        addChild(bullet)
        
        let moveBy = CGVector(dx: direction.dx * bulletRange, dy: direction.dy * bulletRange)
        let travelDuration = TimeInterval(bulletRange / bulletSpeed)
        let move = SKAction.move(by: moveBy, duration: travelDuration)
        let cleanup = SKAction.removeFromParent()
        bullet.run(SKAction.sequence([move, cleanup]))
    }
    
    // MARK: - Loop Principal
    override func update(_ currentTime: TimeInterval) {
        guard gameState == .running else { return }
        
        if runStartTime == nil {
            runStartTime = currentTime
        }
        if let runStartTime {
            currentRunSurvivalTime = max(0, currentTime - runStartTime)
        }
        
        // 1. A Câmara persegue o jogador
        gameCamera.position = player.position
        
        // 2. Movimento do Jogador via Joystick
        if joystick.velocity != .zero {
            player.position.x += joystick.velocity.x * playerMoveSpeed
            player.position.y += joystick.velocity.y * playerMoveSpeed
            
            let angle = atan2(joystick.velocity.y, joystick.velocity.x)
            player.zRotation = angle - .pi/2
        }
        
        // 3. IA dos Inimigos (Perseguição)
        let enemySpeed: CGFloat = 2.0
        enumerateChildNodes(withName: "enemy") { node, _ in
            guard let enemy = node as? SKSpriteNode else { return }
            
            let dx = self.player.position.x - enemy.position.x
            let dy = self.player.position.y - enemy.position.y
            let angle = atan2(dy, dx)
            
            enemy.position.x += cos(angle) * enemySpeed
            enemy.position.y += sin(angle) * enemySpeed
            enemy.zRotation = angle - .pi/2
        }
    }
    
    // MARK: - Colisão
    func didBegin(_ contact: SKPhysicsContact) {
        guard gameState == .running else { return }
        
        let maskA = contact.bodyA.categoryBitMask
        let maskB = contact.bodyB.categoryBitMask
        let collisionMask = maskA | maskB
        
        if collisionMask == (PhysicsCategory.player | PhysicsCategory.enemy) {
            triggerGameOver()
            return
        }
        
        if collisionMask == (PhysicsCategory.bullet | PhysicsCategory.enemy) {
            let enemyNode = maskA == PhysicsCategory.enemy ? contact.bodyA.node : contact.bodyB.node
            let enemyPosition = enemyNode?.position
            
            if maskA == PhysicsCategory.bullet {
                contact.bodyA.node?.removeFromParent()
            } else {
                contact.bodyB.node?.removeFromParent()
            }
            
            let currentHealth = enemyNode?.userData?["health"] as? Int ?? 1
            let enemyRemainingHealth = max(0, currentHealth - bulletDamage)
            if enemyRemainingHealth > 0 {
                enemyNode?.userData?["health"] = enemyRemainingHealth
            } else {
                enemyNode?.removeFromParent()
            }
            
            if enemyRemainingHealth == 0, let enemyPosition {
                spawnDataBit(at: enemyPosition)
            }
        }
        
        if collisionMask == (PhysicsCategory.player | PhysicsCategory.dataBit) {
            let dataBitNode = maskA == PhysicsCategory.dataBit ? contact.bodyA.node : contact.bodyB.node
            collectDataBit(dataBitNode)
        }
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
        
        let panelSize = CGSize(width: 320, height: 180)
        let panel = SKShapeNode(rectOf: panelSize, cornerRadius: 16)
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
        let survivalText = formattedTime(currentRunSurvivalTime)
        let bestText = formattedTime(bestSurvivalTime)
        subtitle.text = "Sobreviveu: \(survivalText) | Recorde: \(bestText)"
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
        if let scene = GameScene(fileNamed: "GameScene") {
            scene.scaleMode = scaleMode
            view?.presentScene(scene, transition: SKTransition.crossFade(withDuration: 0.25))
            return
        }
        
        let scene = GameScene(size: size)
        scene.scaleMode = scaleMode
        view?.presentScene(scene, transition: SKTransition.crossFade(withDuration: 0.25))
    }
    
    // MARK: - Input
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if gameState == .gameOver {
            restartRun()
            return
        }
        
        if gameState == .perkSelection {
            guard let touch = touches.first else { return }
            let location = touch.location(in: gameCamera)
            let tappedNodes = nodes(at: location)
            if let perkNodeName = tappedNodes.compactMap(\.name).first(where: { $0.hasPrefix("perkOption_") }),
               let perk = perkType(from: perkNodeName) {
                pendingPerkSelections = max(0, pendingPerkSelections - 1)
                applyPerk(perk)
                resumeAfterPerkSelection()
            }
            return
        }
        
        super.touchesBegan(touches, with: event)
    }
    
    // MARK: - Persistência
    func loadPersistentProgress() {
        let defaults = UserDefaults.standard
        let storedBestSurvival = defaults.double(forKey: PersistenceKey.bestSurvivalTime)
        let storedDataBits = defaults.integer(forKey: PersistenceKey.totalDataBitsBank)
        let storedHighestLevel = defaults.integer(forKey: PersistenceKey.highestLevelReached)
        
        bestSurvivalTime = storedBestSurvival.isFinite ? max(0, storedBestSurvival) : 0
        totalDataBitsBank = max(0, storedDataBits)
        highestLevelReached = max(1, storedHighestLevel)
    }
    
    func finalizeRunProgress() {
        bestSurvivalTime = max(bestSurvivalTime, currentRunSurvivalTime)
        totalDataBitsBank += max(0, currentRunDataBitsCollected)
        highestLevelReached = max(highestLevelReached, currentLevel)
        persistProgress()
        refreshBestTimeUI()
    }
    
    func persistProgress() {
        let defaults = UserDefaults.standard
        defaults.set(bestSurvivalTime, forKey: PersistenceKey.bestSurvivalTime)
        defaults.set(totalDataBitsBank, forKey: PersistenceKey.totalDataBitsBank)
        defaults.set(highestLevelReached, forKey: PersistenceKey.highestLevelReached)
    }
    
    func refreshBestTimeUI() {
        guard bestTimeLabel != nil else { return }
        bestTimeLabel.text = "Best Survival: \(formattedTime(bestSurvivalTime))"
    }
    
    func formattedTime(_ time: TimeInterval) -> String {
        let totalSeconds = Int(max(0, time.rounded(.down)))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
