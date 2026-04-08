# 🧟 Quad Quarantine
> **Survival Grade:** A high-stakes, campus-survival roguelite built with Swift and SpriteKit.

![Swift](https://img.shields.io/badge/Swift-6.3-orange.svg)
![SpriteKit](https://img.shields.io/badge/Framework-SpriteKit-blue.svg)
![Platform](https://img.shields.io/badge/Platform-iOS-lightgrey.svg)

## 📝 Game Concept
**Quad Quarantine** is a top-down, "survivor-style" arena shooter. You play as a student trapped in a campus parking lot, fighting off endless waves of infected using auto-firing weapons. Survive as long as you can, collect data, and upgrade your gear to live another day.

---

## 🔄 Core Gameplay Loop
1.  **Maneuver:** Use the virtual joystick to dodge the growing horde.
2.  **Auto-Combat:** Your character automatically targets and fires at the nearest threat.
3.  **Collect XP:** Gather **"Data Bits"** dropped by enemies to level up mid-run.
4.  **Evolve:** Choose 1 of 3 random stat-boosting perks every time you level up.
5.  **Upgrade:** After death, spend your total earnings on **Permanent Stat Boosts** in the Main Menu.

---

## 🛠 Technical Implementation

| System | SpriteKit / Swift Component |
| :--- | :--- |
| **Movement** | `SKSpriteNode` updated via `velocity` based on joystick input. |
| **Combat** | `SKAction` timer + `hypot()` distance checking for nearest target. |
| **Physics** | `SKPhysicsBody` with `contactTestBitMask` (No Gravity). |
| **Persistence**| `UserDefaults` for high scores, scrap currency, and upgrade tiers. |
| **UI/UX** | `SKLabelNode` for HUD and `SKShapeNode` for the XP bar. |

> **Pro-Tip:** This project utilizes **Object Pooling** for bullets and enemies to ensure a smooth 60 FPS experience even when the screen is crowded.

---

## 🎯 MVP Scope (Minimum Viable Product)
- [ ] **Player:** Blue square with joystick movement.
- [ ] **Enemy:** Red square that tracks the player's position.
- [ ] **Combat:** Auto-targeting yellow projectiles.
- [ ] **XP System:** Functional level-up pause menu with 3 basic stat perks (Speed, Damage, Fire Rate).
- [ ] **High Score:** Local persistence for "Best Survival Time."

---

## 🗺 Development Roadmap

### **Phase 1: The "Box" Prototype (Core Mechanics)**
- [x] Initial SpriteKit Project Setup.
- [ ] Basic virtual joystick implementation.
- [ ] Enemy spawning logic (Edges of screen).
- [ ] Basic collision detection (Game Over state).

### **Phase 2: Combat & Progression**
- [ ] Nearest-target auto-aim logic.
- [ ] XP Drop logic and UI progress bar.
- [ ] Mid-run "Perk Menu" (Pausing the `SKScene`).
- [ ] Permanent upgrade shop in Main Menu.

### **Phase 3: Juice & Polish**
- [ ] Replace geometric shapes with actual 2D sprites.
- [ ] Particle effects (`SKEmitterNode`) for hits and explosions.
- [ ] Sound effects and background music.
- [ ] Game balance tuning (Scaling difficulty over time).

---

## 🚀 Future Stretch Goals
- **Enemy Variety:** Fast "Sprinters" and high-HP "Tanks."
- **Environment:** Interactive obstacles like fountains or benches.
- **Weapon Variety:** Unlockable weapons like shotguns (spread fire) or lasers.
- **VFX:** Screen shake and dynamic lighting.

---

## 🛠 Installation & Running
1. Clone this repository.
2. Open `QuadQuarantine.xcodeproj` in **Xcode 26.4+**.
3. Select an iOS Simulator or a connected iPhone.
4. Press
