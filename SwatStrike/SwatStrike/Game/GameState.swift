import Foundation

enum GameStatus {
    case playing, paused, levelComplete, gameOver
}

enum WeaponType {
    case pistol, assaultRifle, shotgun
    var name: String {
        switch self { case .pistol: return "PISTOL"
                       case .assaultRifle: return "M4A1"
                       case .shotgun: return "SPAS-12" }
    }
    var maxAmmo: Int {
        switch self { case .pistol: return 15
                       case .assaultRifle: return 30
                       case .shotgun: return 8 }
    }
    var maxReserve: Int {
        switch self { case .pistol: return 60
                       case .assaultRifle: return 120
                       case .shotgun: return 32 }
    }
    var damage: Float {
        switch self { case .pistol: return 25
                       case .assaultRifle: return 18
                       case .shotgun: return 60 }
    }
    var fireRate: TimeInterval {
        switch self { case .pistol: return 0.4
                       case .assaultRifle: return 0.1
                       case .shotgun: return 0.7 }
    }
    var reloadTime: TimeInterval {
        switch self { case .pistol: return 1.5
                       case .assaultRifle: return 2.0
                       case .shotgun: return 2.5 }
    }
    var range: Float {
        switch self { case .pistol: return 30
                       case .assaultRifle: return 60
                       case .shotgun: return 15 }
    }
    var spread: Float {
        switch self { case .pistol: return 0.01
                       case .assaultRifle: return 0.02
                       case .shotgun: return 0.12 }
    }
    var pellets: Int {
        switch self { case .shotgun: return 8
                       default: return 1 }
    }
}

final class GameState {
    static let shared = GameState()
    private init() {}

    var currentLevel: Int = 1
    var playerHealth: Float = 100
    var maxHealth: Float = 100
    var currentWeapon: WeaponType = .assaultRifle
    var ammoInMag: Int = 30
    var reserveAmmo: Int = 120
    var isReloading: Bool = false
    var score: Int = 0
    var killCount: Int = 0
    var status: GameStatus = .playing
    var enemiesRemaining: Int = 0

    func reset(for level: Int) {
        currentLevel = level
        playerHealth = 100
        currentWeapon = .assaultRifle
        ammoInMag = WeaponType.assaultRifle.maxAmmo
        reserveAmmo = WeaponType.assaultRifle.maxReserve
        isReloading = false
        score = 0
        killCount = 0
        status = .playing
    }

    func canFire() -> Bool {
        return !isReloading && ammoInMag > 0 && status == .playing
    }

    func consumeAmmo() {
        ammoInMag = max(0, ammoInMag - 1)
    }

    func reload() {
        let needed = currentWeapon.maxAmmo - ammoInMag
        let take = min(needed, reserveAmmo)
        ammoInMag += take
        reserveAmmo -= take
    }

    func takeDamage(_ amount: Float) {
        playerHealth = max(0, playerHealth - amount)
        if playerHealth <= 0 {
            status = .gameOver
        }
    }

    func heal(_ amount: Float) {
        playerHealth = min(maxHealth, playerHealth + amount)
    }

    func addKill() {
        killCount += 1
        score += 100
        enemiesRemaining = max(0, enemiesRemaining - 1)
        if enemiesRemaining == 0 {
            status = .levelComplete
        }
    }
}
