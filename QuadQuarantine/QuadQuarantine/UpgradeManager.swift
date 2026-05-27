//
//  UpgradeManager.swift
//  QuadQuarantine
//
//  Singleton que gere todos os upgrades permanentes e o banco de Bits.
//

import Foundation

final class UpgradeManager {
    static let shared = UpgradeManager()
    private init() {}

    // MARK: - Upgrade Definition
    struct UpgradeDef {
        let key: String
        let name: String
        let icon: String
        let flavorText: String
        let maxTier: Int
        let costs: [Int]                     // custo por tier (index 0 = tier 1)
        let statLine: (Int) -> String         // texto do efeito para tier N
    }

    // MARK: - Catálogo de upgrades
    let catalogue: [UpgradeDef] = [
        UpgradeDef(
            key: "upg_maxHealth", name: "Reinforced Core", icon: "\u{2665}",
            flavorText: "Stronger body, longer fight.",
            maxTier: 5, costs: [10, 20, 35, 55, 80],
            statLine: { "+\($0 * 25) Max HP" }
        ),
        UpgradeDef(
            key: "upg_damage", name: "Sharp Rounds", icon: "\u{2020}",
            flavorText: "Every shot hits harder.",
            maxTier: 5, costs: [15, 25, 40, 60, 90],
            statLine: { "+\($0) Damage" }
        ),
        UpgradeDef(
            key: "upg_fireRate", name: "Overclock", icon: "\u{1F525}",
            flavorText: "Squeeze more rounds per second.",
            maxTier: 4, costs: [20, 35, 55, 80],
            statLine: { "-\($0 * 8)% Fire Interval" }
        ),
        UpgradeDef(
            key: "upg_moveSpeed", name: "Running Shoes", icon: "\u{26A1}",
            flavorText: "Dodge faster, survive longer.",
            maxTier: 4, costs: [15, 25, 40, 60],
            statLine: { "+\($0 * 5)% Speed" }
        ),
        UpgradeDef(
            key: "upg_healthRegen", name: "Nano Repair", icon: "\u{1F49A}",
            flavorText: "Passive regeneration every second.",
            maxTier: 4, costs: [20, 35, 55, 80],
            statLine: { "+\($0)/s Regen" }
        ),
        UpgradeDef(
            key: "upg_bitDropRate", name: "Scavenger", icon: "\u{2B21}",
            flavorText: "More Bits drop from every kill.",
            maxTier: 3, costs: [25, 45, 70],
            statLine: { "+\($0 * 8)% Drop Chance" }
        ),
        UpgradeDef(
            key: "upg_xpBonus", name: "Scholar", icon: "\u{1F4E1}",
            flavorText: "More XP per DataBit collected.",
            maxTier: 3, costs: [30, 50, 75],
            statLine: { "+\($0 * 15)% XP Gain" }
        ),
    ]

    // MARK: - Banco de Bits permanente
    private let bankKey = "perm_bitsBank"

    var bitsBank: Int {
        get { max(0, UserDefaults.standard.integer(forKey: bankKey)) }
        set { UserDefaults.standard.set(max(0, newValue), forKey: bankKey) }
    }

    // MARK: - Tier helpers
    func tier(for key: String) -> Int {
        UserDefaults.standard.integer(forKey: key)
    }
    private func setTier(_ t: Int, for key: String) {
        UserDefaults.standard.set(t, forKey: key)
    }

    // MARK: - Compra
    func canPurchase(_ def: UpgradeDef) -> Bool {
        let t = tier(for: def.key)
        return t < def.maxTier && bitsBank >= def.costs[t]
    }

    @discardableResult
    func purchase(_ def: UpgradeDef) -> Bool {
        guard canPurchase(def) else { return false }
        let t = tier(for: def.key)
        bitsBank -= def.costs[t]
        setTier(t + 1, for: def.key)
        return true
    }

    // MARK: - Bónus calculados (lidos pelo GameScene no início de cada run)
    var bonusMaxHealth: Int        { tier(for: "upg_maxHealth") * 25 }
    var bonusDamage: Int           { tier(for: "upg_damage") }
    var fireRateMultiplier: Double { 1.0 - Double(tier(for: "upg_fireRate")) * 0.08 }
    var speedMultiplier: Double    { 1.0 + Double(tier(for: "upg_moveSpeed")) * 0.05 }
    var bonusHealthRegen: Double   { Double(tier(for: "upg_healthRegen")) }
    var extraBitDropChance: Double { Double(tier(for: "upg_bitDropRate")) * 0.08 }
    var xpMultiplier: Double       { 1.0 + Double(tier(for: "upg_xpBonus")) * 0.15 }

    // MARK: - Reset total (usado no PlayerStatsScene)
    func resetAll() {
        catalogue.forEach { UserDefaults.standard.removeObject(forKey: $0.key) }
        UserDefaults.standard.removeObject(forKey: bankKey)
    }
}
