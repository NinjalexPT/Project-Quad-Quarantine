//
//  Joystick.swift
//  QuadQuarantine
//
//  Created by Hugo Miguel Ribeiro Oliveira on 15/04/2026.
//

import SpriteKit

class Joystick: SKNode {
    let base: SKShapeNode
    let knob: SKShapeNode
    let radius: CGFloat

    // Direção atual do joystick (valores entre -1 e 1)
    var velocity = CGPoint.zero

    init(radius: CGFloat) {
        self.radius = radius

        // Criar a base (o círculo exterior)
        base = SKShapeNode(circleOfRadius: radius)
        base.strokeColor = .white
        base.lineWidth = 2
        base.alpha = 0.5

        // Criar o manípulo (o círculo que movemos)
        knob = SKShapeNode(circleOfRadius: radius * 0.4)
        knob.fillColor = .white
        knob.alpha = 0.8

        super.init()

        addChild(base)
        addChild(knob)
        self.isUserInteractionEnabled = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Toques
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        // Calcular a distância do toque ao centro
        let distance = hypot(location.x, location.y)

        // Se a distância for maior que o raio, limitamos o manípulo à borda
        if distance > radius {
            let angle = atan2(location.y, location.x)
            knob.position = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
        } else {
            knob.position = location
        }

        // Calcular a velocidade/direção (normalizada para -1 a 1)
        velocity = CGPoint(x: knob.position.x / radius, y: knob.position.y / radius)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Quando largamos, o manípulo volta ao centro e a velocidade a zero
        let reset = SKAction.move(to: .zero, duration: 0.1)
        knob.run(reset)
        velocity = .zero
    }
}
