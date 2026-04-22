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
    
    enum GameState {
        case running
        case gameOver
    }
    
    // MARK: - Propriedades
    var player: SKSpriteNode!
    var joystick: Joystick!
    let gameCamera = SKCameraNode()
    var gameState: GameState = .running
    private let gameOverOverlayName = "gameOverOverlay"
    
    // MARK: - Ciclo de Vida
    override func didMove(to view: SKView) {
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
        startEnemySpawner()
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
        player.physicsBody?.contactTestBitMask = PhysicsCategory.enemy
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
    
    // MARK: - Loop Principal
    override func update(_ currentTime: TimeInterval) {
        guard gameState == .running else { return }
        
        // 1. A Câmara persegue o jogador
        gameCamera.position = player.position
        
        // 2. Movimento do Jogador via Joystick
        let speed: CGFloat = 5.0
        if joystick.velocity != .zero {
            player.position.x += joystick.velocity.x * speed
            player.position.y += joystick.velocity.y * speed
            
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
        }
    }
    
    // MARK: - Estado de Jogo
    func triggerGameOver() {
        guard gameState == .running else { return }
        gameState = .gameOver
        
        removeAction(forKey: "enemySpawner")
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
        subtitle.text = "Toque para reiniciar"
        subtitle.fontSize = 18
        subtitle.fontColor = .lightGray
        subtitle.position = CGPoint(x: 0, y: -35)
        overlay.addChild(subtitle)
        
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
        
        super.touchesBegan(touches, with: event)
    }
}
