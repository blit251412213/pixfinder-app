import SceneKit
import UIKit

// MARK: - EnemyNode

final class EnemyNode: SCNNode {

    enum EnemyState { case idle, patrol, chase, attack, dead }

    // Config
    private let maxHealth: Float
    private(set) var health: Float
    private let moveSpeed: Float
    private let attackRange: Float
    private let attackDamage: Float
    private let attackCooldown: TimeInterval
    private let detectionRange: Float

    // State
    private(set) var state: EnemyState = .idle
    private var lastAttackTime: TimeInterval = 0
    private var patrolTarget: SCNVector3 = .init(0, 1, 0)
    private var patrolWaitTimer: TimeInterval = 0
    private let patrolRadius: Float = 8
    private var isAlive: Bool = true

    // References
    weak var playerNode: SCNNode?
    var onDeath: (() -> Void)?
    var onDamagePlayer: ((Float) -> Void)?

    // Body parts
    private let bodyNode = SCNNode()
    private let headNode = SCNNode()
    private var healthBarNode: SCNNode?

    init(level: Int) {
        let scaleFactor = Float(level)
        maxHealth = 60 + scaleFactor * 20
        health = maxHealth
        moveSpeed = 2.5 + scaleFactor * 0.4
        attackRange = 5.0
        attackDamage = 8.0 + scaleFactor * 2.0
        attackCooldown = max(0.8, 1.5 - Double(level) * 0.15)
        detectionRange = 18.0 + scaleFactor * 2.0
        super.init()
        buildGeometry(level: level)
        setupPhysics()
        setRandomPatrolTarget()
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Build

    private func buildGeometry(level: Int) {
        // Torso
        let torsoColor: UIColor
        switch level {
        case 1: torsoColor = UIColor(red: 0.1, green: 0.3, blue: 0.1, alpha: 1)   // SWAT green
        case 2: torsoColor = UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1) // Tactical black
        default: torsoColor = UIColor(red: 0.4, green: 0.05, blue: 0.05, alpha: 1) // Elite red
        }

        let torso = SCNBox(width: 0.7, height: 1.0, length: 0.4, chamferRadius: 0.05)
        torso.firstMaterial = SCNMaterial.pbr(color: torsoColor, metalness: 0.1, roughness: 0.7)
        bodyNode.geometry = torso
        bodyNode.position = SCNVector3(0, 0.5, 0)
        addChildNode(bodyNode)

        // Vest / armor plate
        let vestColor = UIColor(red: 0.25, green: 0.22, blue: 0.18, alpha: 1)
        let vest = SCNBox(width: 0.72, height: 0.55, length: 0.42, chamferRadius: 0.04)
        vest.firstMaterial = SCNMaterial.pbr(color: vestColor, metalness: 0.05, roughness: 0.85)
        let vestNode = SCNNode(geometry: vest)
        vestNode.position = SCNVector3(0, 0.05, 0)
        bodyNode.addChildNode(vestNode)

        // Head
        let head = SCNSphere(radius: 0.22)
        let skinColor = UIColor(red: 0.8, green: 0.65, blue: 0.5, alpha: 1)
        head.firstMaterial = SCNMaterial.pbr(color: skinColor, roughness: 0.8)
        headNode.geometry = head
        headNode.position = SCNVector3(0, 1.27, 0)
        addChildNode(headNode)

        // Helmet
        let helmet = SCNSphere(radius: 0.24)
        let helmetColor = UIColor(red: 0.15, green: 0.18, blue: 0.12, alpha: 1)
        helmet.firstMaterial = SCNMaterial.pbr(color: helmetColor, metalness: 0.2, roughness: 0.6)
        let helmetNode = SCNNode(geometry: helmet)
        helmetNode.position = SCNVector3(0, 0.06, 0)
        headNode.addChildNode(helmetNode)

        // Visor
        let visor = SCNBox(width: 0.36, height: 0.1, length: 0.35, chamferRadius: 0.02)
        visor.firstMaterial = SCNMaterial.pbr(color: UIColor(red: 0.4, green: 0.6, blue: 0.9, alpha: 0.7),
                                               metalness: 0.8, roughness: 0.1)
        let visorNode = SCNNode(geometry: visor)
        visorNode.position = SCNVector3(0, -0.04, 0.2)
        headNode.addChildNode(visorNode)

        // Arms
        armGeometry(at: SCNVector3(-0.5, 0.55, 0))
        armGeometry(at: SCNVector3(0.5, 0.55, 0))

        // Legs
        legGeometry(at: SCNVector3(-0.2, -0.6, 0))
        legGeometry(at: SCNVector3(0.2, -0.6, 0))

        // Weapon in right hand
        let gunBarrel = SCNBox(width: 0.06, height: 0.06, length: 0.55, chamferRadius: 0.01)
        gunBarrel.firstMaterial = SCNMaterial.pbr(color: UIColor(white: 0.15, alpha: 1),
                                                   metalness: 0.9, roughness: 0.3)
        let gunNode = SCNNode(geometry: gunBarrel)
        gunNode.position = SCNVector3(0.55, 0.5, -0.3)
        addChildNode(gunNode)

        // Health bar
        setupHealthBar()

        // Breathing idle animation
        let breathe = SCNAction.sequence([
            .scale(to: 1.02, duration: 1.2),
            .scale(to: 0.98, duration: 1.2)
        ])
        bodyNode.runAction(.repeatForever(breathe))
    }

    private func armGeometry(at position: SCNVector3) {
        let isLeft = position.x < 0
        let arm = SCNBox(width: 0.2, height: 0.6, length: 0.2, chamferRadius: 0.05)
        arm.firstMaterial = SCNMaterial.pbr(color: UIColor(red: 0.1, green: 0.28, blue: 0.1, alpha: 1),
                                             roughness: 0.7)
        let armNode = SCNNode(geometry: arm)
        armNode.position = position

        // Swing arm animation
        let swing = SCNAction.sequence([
            .rotateTo(x: CGFloat(isLeft ? 0.3 : -0.3), y: 0, z: 0, duration: 0.5),
            .rotateTo(x: CGFloat(isLeft ? -0.3 : 0.3), y: 0, z: 0, duration: 0.5)
        ])
        armNode.runAction(.repeatForever(swing))
        addChildNode(armNode)
    }

    private func legGeometry(at position: SCNVector3) {
        let isLeft = position.x < 0
        let leg = SCNBox(width: 0.24, height: 0.7, length: 0.24, chamferRadius: 0.04)
        leg.firstMaterial = SCNMaterial.pbr(color: UIColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1),
                                             roughness: 0.85)
        let legNode = SCNNode(geometry: leg)
        legNode.position = position

        let stride = SCNAction.sequence([
            .rotateTo(x: CGFloat(isLeft ? 0.4 : -0.4), y: 0, z: 0, duration: 0.35),
            .rotateTo(x: CGFloat(isLeft ? -0.4 : 0.4), y: 0, z: 0, duration: 0.35)
        ])
        legNode.runAction(.repeatForever(stride))
        addChildNode(legNode)
    }

    private func setupHealthBar() {
        let barWidth: CGFloat = 0.8
        let barHeight: CGFloat = 0.1

        let bgBar = SCNBox(width: barWidth, height: barHeight, length: 0.02, chamferRadius: 0)
        bgBar.firstMaterial = SCNMaterial.pbr(color: UIColor(white: 0.2, alpha: 0.8))
        let bgNode = SCNNode(geometry: bgBar)

        let fgBar = SCNBox(width: barWidth, height: barHeight, length: 0.03, chamferRadius: 0)
        fgBar.firstMaterial = SCNMaterial.pbr(color: UIColor(red: 0.1, green: 0.9, blue: 0.1, alpha: 1),
                                               emission: UIColor(red: 0.1, green: 0.9, blue: 0.1, alpha: 0.5))
        let fgNode = SCNNode(geometry: fgBar)
        fgNode.name = "healthBar"

        let container = SCNNode()
        container.addChildNode(bgNode)
        container.addChildNode(fgNode)
        container.position = SCNVector3(0, 1.7, 0)
        container.constraints = [SCNBillboardConstraint()]
        addChildNode(container)
        healthBarNode = fgNode
    }

    private func setupPhysics() {
        let capsule = SCNCapsule(capRadius: 0.4, height: 1.8)
        let shape = SCNPhysicsShape(geometry: capsule, options: nil)
        physicsBody = SCNPhysicsBody(type: .kinematic, shape: shape)
        physicsBody?.categoryBitMask = PhysicsCategory.enemy
        physicsBody?.collisionBitMask = PhysicsCategory.wall | PhysicsCategory.player
        physicsBody?.contactTestBitMask = PhysicsCategory.bullet
    }

    // MARK: - AI Update

    func update(deltaTime: TimeInterval, currentTime: TimeInterval) {
        guard isAlive, let player = playerNode else { return }

        let dist = distance(to: player)

        switch state {
        case .idle:
            if dist < detectionRange {
                transitionTo(.chase)
            } else {
                patrolWaitTimer -= deltaTime
                if patrolWaitTimer <= 0 { transitionTo(.patrol) }
            }

        case .patrol:
            let toTarget = patrolTarget - position
            let d = length(toTarget)
            if d < 0.5 {
                transitionTo(.idle)
                patrolWaitTimer = Double.random(in: 1...3)
            } else {
                let dir = normalize(toTarget)
                let step = Float(deltaTime) * moveSpeed * 0.6
                position = SCNVector3(
                    position.x + dir.x * step,
                    position.y,
                    position.z + dir.z * step
                )
                faceDirection(dir)
            }
            if dist < detectionRange { transitionTo(.chase) }

        case .chase:
            if dist <= attackRange {
                transitionTo(.attack)
            } else if dist > detectionRange * 1.5 {
                transitionTo(.patrol)
                setRandomPatrolTarget()
            } else {
                let dir = normalize(player.position - position)
                let step = Float(deltaTime) * moveSpeed
                let newPos = SCNVector3(
                    position.x + dir.x * step,
                    position.y,
                    position.z + dir.z * step
                )
                position = newPos
                faceDirection(dir)
            }

        case .attack:
            faceDirection(normalize(player.position - position))
            if dist > attackRange * 1.3 {
                transitionTo(.chase)
            } else if currentTime - lastAttackTime >= attackCooldown {
                lastAttackTime = currentTime
                onDamagePlayer?(attackDamage)
                playAttackAnimation()
            }

        case .dead:
            break
        }
    }

    private func transitionTo(_ newState: EnemyState) {
        state = newState
        if newState == .patrol { setRandomPatrolTarget() }
    }

    // MARK: - Hit / Death

    func takeDamage(_ amount: Float) {
        guard isAlive else { return }
        health -= amount
        updateHealthBar()
        if health <= 0 {
            die()
        } else {
            flashHit()
        }
    }

    private func die() {
        guard isAlive else { return }
        isAlive = false
        state = .dead

        physicsBody = nil

        // Fall over
        let fall = SCNAction.group([
            .rotateBy(x: CGFloat.pi / 2, y: 0, z: 0, duration: 0.4),
            .move(by: SCNVector3(0, -0.8, 0), duration: 0.4)
        ])
        let fade = SCNAction.sequence([
            .wait(duration: 2.0),
            .fadeOut(duration: 0.5),
            .removeFromParentNode()
        ])
        runAction(.sequence([fall, fade]))
        onDeath?()
    }

    private func flashHit() {
        let flash = SCNAction.sequence([
            .customAction(duration: 0.1) { node, _ in
                node.childNodes.forEach { $0.geometry?.firstMaterial?.emission.contents =
                    UIColor(red: 1, green: 0, blue: 0, alpha: 0.8) }
            },
            .customAction(duration: 0.1) { node, _ in
                node.childNodes.forEach { $0.geometry?.firstMaterial?.emission.contents = UIColor.black }
            }
        ])
        runAction(flash)
    }

    private func playAttackAnimation() {
        let recoil = SCNAction.sequence([
            .move(by: SCNVector3(0, 0, 0.15), duration: 0.05),
            .move(by: SCNVector3(0, 0, -0.15), duration: 0.1)
        ])
        runAction(recoil)
    }

    private func updateHealthBar() {
        guard let bar = healthBarNode,
              let geom = bar.geometry as? SCNBox else { return }
        let ratio = CGFloat(max(0, health / maxHealth))
        geom.width = 0.8 * ratio
        bar.position = SCNVector3(Float(-0.4 + 0.4 * ratio), 0, 0)

        let r = Float(1 - ratio)
        let g = Float(ratio)
        bar.geometry?.firstMaterial?.diffuse.contents = UIColor(red: CGFloat(r), green: CGFloat(g), blue: 0, alpha: 1)
    }

    // MARK: - Patrol

    private func setRandomPatrolTarget() {
        let angle = Float.random(in: 0...(Float.pi * 2))
        let radius = Float.random(in: 2...patrolRadius)
        patrolTarget = SCNVector3(
            position.x + cos(angle) * radius,
            position.y,
            position.z + sin(angle) * radius
        )
    }

    // MARK: - Math

    private func distance(to node: SCNNode) -> Float {
        let dx = node.position.x - position.x
        let dz = node.position.z - position.z
        return sqrt(dx * dx + dz * dz)
    }

    private func normalize(_ v: SCNVector3) -> SCNVector3 {
        let len = sqrt(v.x * v.x + v.z * v.z)
        guard len > 0.001 else { return SCNVector3(0, 0, 1) }
        return SCNVector3(v.x / len, 0, v.z / len)
    }

    private func length(_ v: SCNVector3) -> Float {
        sqrt(v.x * v.x + v.z * v.z)
    }

    private func faceDirection(_ dir: SCNVector3) {
        let angle = atan2(dir.x, dir.z)
        eulerAngles = SCNVector3(0, angle, 0)
    }
}

// MARK: - SCNVector3 helpers for EnemyNode

private func -(lhs: SCNVector3, rhs: SCNVector3) -> SCNVector3 {
    SCNVector3(lhs.x - rhs.x, lhs.y - rhs.y, lhs.z - rhs.z)
}
private func +(lhs: SCNVector3, rhs: SCNVector3) -> SCNVector3 {
    SCNVector3(lhs.x + rhs.x, lhs.y + rhs.y, lhs.z + rhs.z)
}

// MARK: - SCNMaterial PBR extension (for EnemyNode)

private extension SCNMaterial {
    static func pbr(color: UIColor,
                    metalness: CGFloat = 0,
                    roughness: CGFloat = 0.8,
                    emission: UIColor? = nil) -> SCNMaterial {
        let mat = SCNMaterial()
        mat.lightingModel = .physicallyBased
        mat.diffuse.contents = color
        mat.metalness.contents = metalness
        mat.roughness.contents = roughness
        if let e = emission { mat.emission.contents = e }
        return mat
    }
}
