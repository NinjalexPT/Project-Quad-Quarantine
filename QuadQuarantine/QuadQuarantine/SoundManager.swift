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
    private let mutedKey         = "soundMuted"
    private let musicVolumeKey   = "musicVolume"
    private let effectsVolumeKey = "effectsVolume"

    // MARK: - Mute
    var isMuted: Bool {
        get { UserDefaults.standard.bool(forKey: mutedKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: mutedKey)
            if newValue { musicPlayer?.pause() }
            else        { musicPlayer?.volume = musicVolume; musicPlayer?.play() }
        }
    }

    // MARK: - Volume da Música: 0.0 – 1.0  (default 0.7)
    var musicVolume: Float {
        get {
            let stored = UserDefaults.standard.object(forKey: musicVolumeKey)
            return stored != nil ? UserDefaults.standard.float(forKey: musicVolumeKey) : 0.7
        }
        set {
            UserDefaults.standard.set(newValue, forKey: musicVolumeKey)
            musicPlayer?.volume = newValue
        }
    }

    // MARK: - Volume dos Efeitos: 0.0 – 1.0  (default 0.8)
    var effectsVolume: Float {
        get {
            let stored = UserDefaults.standard.object(forKey: effectsVolumeKey)
            return stored != nil ? UserDefaults.standard.float(forKey: effectsVolumeKey) : 0.8
        }
        set {
            UserDefaults.standard.set(newValue, forKey: effectsVolumeKey)
        }
    }

    // MARK: - Retrocompatibilidade
    var volume: Float {
        get { effectsVolume }
        set { effectsVolume = newValue; musicVolume = newValue }
    }

    // MARK: - Música de fundo
    private var musicPlayer: AVAudioPlayer?

    func playMusic(named fileName: String, loop: Bool = true) {
        guard !isMuted else { return }
        guard let url = Bundle.main.url(forResource: fileName, withExtension: nil) else { return }
        do {
            musicPlayer = try AVAudioPlayer(contentsOf: url)
            musicPlayer?.numberOfLoops = loop ? -1 : 0
            musicPlayer?.volume = musicVolume
            musicPlayer?.play()
        } catch { print("SoundManager: erro ao carregar música \(fileName) — \(error)") }
    }

    func stopMusic() { musicPlayer?.stop(); musicPlayer = nil }

    // MARK: - Efeitos sonoros (SKAction, chamados dentro de um SKScene)
    func playEffect(named fileName: String, on node: SKNode) {
        guard !isMuted else { return }
        guard let url = Bundle.main.url(forResource: fileName, withExtension: nil) else { return }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = effectsVolume
            player.play()
            temporaryPlayers.append(player)
            DispatchQueue.main.asyncAfter(deadline: .now() + player.duration + 0.1) { [weak self] in
                self?.temporaryPlayers.removeAll { $0 === player }
            }
        } catch {}
    }

    private var temporaryPlayers: [AVAudioPlayer] = []
}
