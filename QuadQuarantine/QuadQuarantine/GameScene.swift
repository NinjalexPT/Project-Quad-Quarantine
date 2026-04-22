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

class GameScene: SKScene {
    
    // MARK: - Propriedades
    var player: SKSpriteNode!
    var joystick: Joystick!
    let gameCamera = SKCameraNode()
    
    // MARK: - Ciclo de Vida
    override func didMove(to view: SKView) {
        // 1. Configurar a âncora e a câmara
        self.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        self.backgroundColor = SKColor.darkGray
        
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
}
