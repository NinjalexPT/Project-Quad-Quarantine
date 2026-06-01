//
//  SoundManager.swift
//  QuadQuarantine
//
//  Singleton centralizado para controlo de som.
//  Usa SKAction para efeitos (compatível com SpriteKit) e AVAudioPlayer para música.
//

import SpriteKit
import AVFoundation

final class SoundManager {
    static let shared = SoundManager()
    private init() {}

    // MARK: - Persistence Keys
    private let mutedKey  = "soundMuted"
    private let volumeKey = "soundVolume"

    // MARK: - Estado
    var isMuted: Bool {
        get { UserDefaults.standard.bool(forKey: mutedKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: mutedKey)
            if newValue { musicPlayer?.pause() }
            else        { musicPlayer?.play()  }
        }
    }

    /// Volume geral: 0.0 – 1.0  (default 1.0)
    var volume: Float {
        get {
            let v = UserDefaults.standard.float(forKey: volumeKey)
            return v == 0 && !UserDefaults.standard.bool(forKey: "soundVolumeSet") ? 1.0 : v
        }
        set {
            UserDefaults.standard.set(newValue, forKey: volumeKey)
            UserDefaults.standard.set(true,     forKey: "soundVolumeSet")
            musicPlayer?.volume = newValue
        }
    }

    // MARK: - Música de fundo
    private var musicPlayer: AVAudioPlayer?

    func playMusic(named fileName: String, loop: Bool = true) {
        guard !isMuted else { return }
        guard let url = Bundle.main.url(forResource: fileName, withExtension: nil) else { return }
        do {
            musicPlayer = try AVAudioPlayer(contentsOf: url)
            musicPlayer?.numberOfLoops = loop ? -1 : 0
            musicPlayer?.volume = volume
            musicPlayer?.play()
        } catch { print("SoundManager: erro ao carregar música \(fileName) — \(error)") }
    }

    func stopMusic() { musicPlayer?.stop(); musicPlayer = nil }

    // MARK: - Efeitos sonoros (SKAction, chamados dentro de um SKScene)
    func playEffect(named fileName: String, on node: SKNode) {
        guard !isMuted else { return }
        // SKAction não tem controlo de volume nativo; para volumes < 1 usamos AVAudioPlayer pontual
        if volume >= 0.99 {
            node.run(SKAction.playSoundFileNamed(fileName, waitForCompletion: false))
        } else {
            guard let url = Bundle.main.url(forResource: fileName, withExtension: nil) else { return }
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.volume = volume
                player.play()
                // Mantemos referência temporária para o player não ser desalocado antes de terminar
                temporaryPlayers.append(player)
                DispatchQueue.main.asyncAfter(deadline: .now() + player.duration + 0.1) { [weak self] in
                    self?.temporaryPlayers.removeAll { $0 === player }
                }
            } catch {}
        }
    }

    private var temporaryPlayers: [AVAudioPlayer] = []
}
