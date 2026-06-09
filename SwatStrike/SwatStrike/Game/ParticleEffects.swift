import SceneKit
import UIKit

final class ParticleEffects {

    // MARK: - Muzzle Flash

    static func muzzleFlash() -> SCNParticleSystem {
        let ps = SCNParticleSystem()
        ps.birthRate = 800
        ps.emissionDuration = 0.04
        ps.particleLifeSpan = 0.06
        ps.particleSize = 0.03
        ps.particleColor = UIColor(red: 1, green: 0.8, blue: 0.2, alpha: 1)
        ps.particleColorVariation = SCNVector4(0.1, 0.1, 0, 0)
        ps.speedFactor = 1.0
        ps.particleVelocity = 3.0
        ps.particleVelocityVariation = 2.0
        ps.emitterShape = SCNCone(topRadius: 0, bottomRadius: 0.04, height: 0.05)
        ps.isAffectedByGravity = false
        ps.blendMode = .additive
        ps.loops = false
        return ps
    }

    // MARK: - Blood Hit

    static func bloodSplatter(at position: SCNVector3, in scene: SCNScene) {
        let ps = SCNParticleSystem()
        ps.birthRate = 150
        ps.emissionDuration = 0.08
        ps.particleLifeSpan = 0.5
        ps.particleLifeSpanVariation = 0.2
        ps.particleSize = 0.06
        ps.particleSizeVariation = 0.04
        ps.particleColor = UIColor(red: 0.7, green: 0, blue: 0, alpha: 1)
        ps.particleVelocity = 4.0
        ps.particleVelocityVariation = 3.0
        ps.isAffectedByGravity = true
        ps.loops = false
        ps.blendMode = .alpha

        let node = SCNNode()
        node.position = position
        scene.rootNode.addChildNode(node)
        node.addParticleSystem(ps)

        // Remove after effect ends
        node.runAction(.sequence([.wait(duration: 1.0), .removeFromParentNode()]))
    }

    // MARK: - Bullet Impact (wall)

    static func bulletImpact(at position: SCNVector3, in scene: SCNScene) {
        let ps = SCNParticleSystem()
        ps.birthRate = 60
        ps.emissionDuration = 0.05
        ps.particleLifeSpan = 0.4
        ps.particleSize = 0.04
        ps.particleColor = UIColor(red: 0.7, green: 0.6, blue: 0.4, alpha: 1)
        ps.particleVelocity = 3.0
        ps.particleVelocityVariation = 2.0
        ps.isAffectedByGravity = true
        ps.loops = false

        let node = SCNNode()
        node.position = position
        scene.rootNode.addChildNode(node)
        node.addParticleSystem(ps)
        node.runAction(.sequence([.wait(duration: 0.5), .removeFromParentNode()]))
    }

    // MARK: - Explosion

    static func explosion(at position: SCNVector3, in scene: SCNScene) {
        // Fireball
        let fireball = SCNParticleSystem()
        fireball.birthRate = 500
        fireball.emissionDuration = 0.15
        fireball.particleLifeSpan = 0.6
        fireball.particleSize = 0.3
        fireball.particleSizeVariation = 0.2
        fireball.particleColor = UIColor(red: 1, green: 0.4, blue: 0, alpha: 1)
        fireball.particleVelocity = 6.0
        fireball.particleVelocityVariation = 4.0
        fireball.isAffectedByGravity = false
        fireball.blendMode = .additive
        fireball.loops = false

        // Smoke
        let smoke = SCNParticleSystem()
        smoke.birthRate = 80
        smoke.emissionDuration = 0.3
        smoke.particleLifeSpan = 2.0
        smoke.particleSize = 0.5
        smoke.particleSizeVariation = 0.3
        smoke.particleColor = UIColor(white: 0.3, alpha: 0.7)
        smoke.particleVelocity = 2.0
        smoke.isAffectedByGravity = false
        smoke.loops = false

        let node = SCNNode()
        node.position = position
        scene.rootNode.addChildNode(node)
        node.addParticleSystem(fireball)
        node.addParticleSystem(smoke)

        // Flash light
        let flash = SCNLight()
        flash.type = .omni
        flash.color = UIColor(red: 1, green: 0.6, blue: 0.1, alpha: 1)
        flash.intensity = 2000
        flash.attenuationEndDistance = 20
        node.light = flash

        let fadeLight = SCNAction.sequence([
            .customAction(duration: 0.3) { n, t in
                (n.light as? SCNLight)?.intensity = CGFloat(2000 * (1 - t / 0.3))
            }
        ])
        node.runAction(.sequence([fadeLight, .wait(duration: 2), .removeFromParentNode()]))
    }

    // MARK: - Death Smoke

    static func deathEffect(at position: SCNVector3, in scene: SCNScene) {
        let ps = SCNParticleSystem()
        ps.birthRate = 100
        ps.emissionDuration = 0.2
        ps.particleLifeSpan = 1.5
        ps.particleSize = 0.15
        ps.particleColor = UIColor(white: 0.25, alpha: 0.8)
        ps.particleVelocity = 2.0
        ps.particleVelocityVariation = 1.5
        ps.isAffectedByGravity = false
        ps.loops = false

        let node = SCNNode()
        node.position = SCNVector3(position.x, position.y + 0.5, position.z)
        scene.rootNode.addChildNode(node)
        node.addParticleSystem(ps)
        node.runAction(.sequence([.wait(duration: 2.0), .removeFromParentNode()]))
    }

    // MARK: - Level Complete

    static func victory(in scene: SCNScene) {
        let colors: [UIColor] = [.red, .orange, .yellow, .green, .cyan, .blue, .magenta]
        for (i, color) in colors.enumerated() {
            let ps = SCNParticleSystem()
            ps.birthRate = 40
            ps.emissionDuration = 0.5
            ps.particleLifeSpan = 3.0
            ps.particleSize = 0.12
            ps.particleColor = color
            ps.particleVelocity = 8.0
            ps.particleVelocityVariation = 4.0
            ps.isAffectedByGravity = true
            ps.loops = false

            let angle = Float(i) * (Float.pi * 2 / Float(colors.count))
            let node = SCNNode()
            node.position = SCNVector3(cos(angle) * 3, 2, sin(angle) * 3)
            scene.rootNode.addChildNode(node)
            node.addParticleSystem(ps)
            node.runAction(.sequence([.wait(duration: 4.0), .removeFromParentNode()]))
        }
    }
}
