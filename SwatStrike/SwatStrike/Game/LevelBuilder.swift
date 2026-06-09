import SceneKit
import UIKit

// MARK: - Material Helpers

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
        if let e = emission {
            mat.emission.contents = e
        }
        mat.isDoubleSided = false
        return mat
    }
}

// MARK: - LevelBuilder

final class LevelBuilder {

    static func build(level: Int, scene: SCNScene) -> [EnemyNode] {
        switch level {
        case 1: return buildWarehouse(scene: scene)
        case 2: return buildOffice(scene: scene)
        case 3: return buildRooftop(scene: scene)
        default: return buildWarehouse(scene: scene)
        }
    }

    // MARK: Level 1 — Warehouse

    private static func buildWarehouse(scene: SCNScene) -> [EnemyNode] {
        let root = scene.rootNode

        // Floor
        addBox(to: root, size: SCNVector3(60, 0.5, 60), position: SCNVector3(0, -0.25, 0),
               material: .pbr(color: UIColor(red: 0.25, green: 0.22, blue: 0.18, alpha: 1), roughness: 0.95))

        // Ceiling
        addBox(to: root, size: SCNVector3(60, 0.5, 60), position: SCNVector3(0, 6.25, 0),
               material: .pbr(color: UIColor(red: 0.15, green: 0.14, blue: 0.13, alpha: 1), roughness: 0.9))

        // Walls
        let wallMat = SCNMaterial.pbr(color: UIColor(red: 0.3, green: 0.28, blue: 0.24, alpha: 1), roughness: 0.9)
        addBox(to: root, size: SCNVector3(60, 7, 0.5), position: SCNVector3(0, 3, -30), material: wallMat)
        addBox(to: root, size: SCNVector3(60, 7, 0.5), position: SCNVector3(0, 3, 30), material: wallMat)
        addBox(to: root, size: SCNVector3(0.5, 7, 60), position: SCNVector3(-30, 3, 0), material: wallMat)
        addBox(to: root, size: SCNVector3(0.5, 7, 60), position: SCNVector3(30, 3, 0), material: wallMat)

        // Crates
        let crateMat = SCNMaterial.pbr(color: UIColor(red: 0.55, green: 0.42, blue: 0.25, alpha: 1), roughness: 0.8)
        crateCluster(root: root, center: SCNVector3(-10, 0, -10), mat: crateMat)
        crateCluster(root: root, center: SCNVector3(12, 0, -8), mat: crateMat)
        crateCluster(root: root, center: SCNVector3(-8, 0, 12), mat: crateMat)
        crateCluster(root: root, center: SCNVector3(15, 0, 15), mat: crateMat)
        crateCluster(root: root, center: SCNVector3(-15, 0, -20), mat: crateMat)

        // Industrial pillars
        let pillarMat = SCNMaterial.pbr(color: UIColor(red: 0.4, green: 0.38, blue: 0.35, alpha: 1),
                                         metalness: 0.3, roughness: 0.7)
        for x in stride(from: -20.0, through: 20.0, by: 20.0) {
            for z in stride(from: -20.0, through: 20.0, by: 20.0) {
                addBox(to: root, size: SCNVector3(1.2, 7, 1.2),
                       position: SCNVector3(Float(x), 3, Float(z)), material: pillarMat)
            }
        }

        // Overhead lights
        addWarehouseLights(to: root)

        // Ambient
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.color = UIColor(white: 0.08, alpha: 1)
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        root.addChildNode(ambientNode)

        // Enemies — warehouse
        let spawnPoints: [SCNVector3] = [
            SCNVector3(-18, 1, -18), SCNVector3(18, 1, -18),
            SCNVector3(-18, 1, 18), SCNVector3(18, 1, 18),
            SCNVector3(0, 1, -25), SCNVector3(-25, 1, 0),
            SCNVector3(25, 1, 5), SCNVector3(8, 1, -20),
            SCNVector3(-8, 1, 20), SCNVector3(20, 1, -5),
            SCNVector3(-12, 1, 5), SCNVector3(5, 1, 22)
        ]
        return spawnEnemies(root: root, positions: spawnPoints, level: 1)
    }

    // MARK: Level 2 — Office

    private static func buildOffice(scene: SCNScene) -> [EnemyNode] {
        let root = scene.rootNode

        let floorMat = SCNMaterial.pbr(color: UIColor(red: 0.18, green: 0.2, blue: 0.22, alpha: 1),
                                        metalness: 0.1, roughness: 0.3)
        addBox(to: root, size: SCNVector3(80, 0.5, 80), position: SCNVector3(0, -0.25, 0), material: floorMat)

        let ceilMat = SCNMaterial.pbr(color: UIColor(white: 0.9, alpha: 1), roughness: 0.95)
        addBox(to: root, size: SCNVector3(80, 0.5, 80), position: SCNVector3(0, 3.75, 0), material: ceilMat)

        // Outer walls
        let wallMat = SCNMaterial.pbr(color: UIColor(red: 0.85, green: 0.85, blue: 0.87, alpha: 1), roughness: 0.9)
        addBox(to: root, size: SCNVector3(80, 4.5, 0.3), position: SCNVector3(0, 1.75, -40), material: wallMat)
        addBox(to: root, size: SCNVector3(80, 4.5, 0.3), position: SCNVector3(0, 1.75, 40), material: wallMat)
        addBox(to: root, size: SCNVector3(0.3, 4.5, 80), position: SCNVector3(-40, 1.75, 0), material: wallMat)
        addBox(to: root, size: SCNVector3(0.3, 4.5, 80), position: SCNVector3(40, 1.75, 0), material: wallMat)

        // Office partition walls
        let partMat = SCNMaterial.pbr(color: UIColor(red: 0.75, green: 0.75, blue: 0.78, alpha: 1), roughness: 0.85)
        officePartitions(root: root, mat: partMat)

        // Office desks
        let deskMat = SCNMaterial.pbr(color: UIColor(red: 0.4, green: 0.3, blue: 0.2, alpha: 1), roughness: 0.6)
        officeFurniture(root: root, mat: deskMat)

        // Fluorescent lights
        officeLights(root: root)

        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.color = UIColor(white: 0.15, alpha: 1)
        let an = SCNNode(); an.light = ambient
        root.addChildNode(an)

        // Enemies — 20
        let positions: [SCNVector3] = [
            SCNVector3(-25, 1, -25), SCNVector3(25, 1, -25),
            SCNVector3(-25, 1, 25), SCNVector3(25, 1, 25),
            SCNVector3(-10, 1, -30), SCNVector3(10, 1, -30),
            SCNVector3(-30, 1, -10), SCNVector3(-30, 1, 10),
            SCNVector3(30, 1, -10), SCNVector3(30, 1, 10),
            SCNVector3(-15, 1, 0), SCNVector3(15, 1, 0),
            SCNVector3(0, 1, -15), SCNVector3(0, 1, 15),
            SCNVector3(-20, 1, 20), SCNVector3(20, 1, -20),
            SCNVector3(-5, 1, -35), SCNVector3(5, 1, 35),
            SCNVector3(-35, 1, 5), SCNVector3(35, 1, -5)
        ]
        return spawnEnemies(root: root, positions: positions, level: 2)
    }

    // MARK: Level 3 — Rooftop

    private static func buildRooftop(scene: SCNScene) -> [EnemyNode] {
        let root = scene.rootNode

        // Sky ambient
        scene.background.contents = UIColor(red: 0.04, green: 0.04, blue: 0.12, alpha: 1)

        let roofMat = SCNMaterial.pbr(color: UIColor(red: 0.22, green: 0.22, blue: 0.24, alpha: 1),
                                       metalness: 0.15, roughness: 0.8)
        addBox(to: root, size: SCNVector3(70, 0.5, 70), position: SCNVector3(0, -0.25, 0), material: roofMat)

        // Perimeter ledge
        let ledgeMat = SCNMaterial.pbr(color: UIColor(red: 0.3, green: 0.3, blue: 0.32, alpha: 1), roughness: 0.7)
        addBox(to: root, size: SCNVector3(70, 1.2, 0.4), position: SCNVector3(0, 0.6, -35), material: ledgeMat)
        addBox(to: root, size: SCNVector3(70, 1.2, 0.4), position: SCNVector3(0, 0.6, 35), material: ledgeMat)
        addBox(to: root, size: SCNVector3(0.4, 1.2, 70), position: SCNVector3(-35, 0.6, 0), material: ledgeMat)
        addBox(to: root, size: SCNVector3(0.4, 1.2, 70), position: SCNVector3(35, 0.6, 0), material: ledgeMat)

        // HVAC units, pipes, cover
        rooftopProps(root: root)

        // Moon / directional light from above-ish
        let sun = SCNLight()
        sun.type = .directional
        sun.color = UIColor(red: 0.5, green: 0.6, blue: 0.9, alpha: 1)
        sun.intensity = 400
        sun.castsShadow = true
        sun.shadowMode = .deferred
        sun.shadowSampleCount = 8
        sun.shadowRadius = 4
        let sunNode = SCNNode(); sunNode.light = sun
        sunNode.eulerAngles = SCNVector3(-Float.pi / 3, Float.pi / 6, 0)
        root.addChildNode(sunNode)

        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.color = UIColor(red: 0.05, green: 0.05, blue: 0.1, alpha: 1)
        let an = SCNNode(); an.light = ambient
        root.addChildNode(an)

        // Enemy spotlights (moving)
        rooftopSearchlights(root: root)

        // Enemies — 30
        var positions: [SCNVector3] = []
        for i in 0..<30 {
            let angle = Float(i) * (Float.pi * 2 / 30)
            let r = Float.random(in: 8...30)
            let x = cos(angle) * r
            let z = sin(angle) * r
            positions.append(SCNVector3(x, 1, z))
        }
        return spawnEnemies(root: root, positions: positions, level: 3)
    }

    // MARK: - Helpers

    @discardableResult
    private static func addBox(to parent: SCNNode,
                                size: SCNVector3,
                                position: SCNVector3,
                                material: SCNMaterial) -> SCNNode {
        let box = SCNBox(width: CGFloat(size.x), height: CGFloat(size.y),
                         length: CGFloat(size.z), chamferRadius: 0)
        box.firstMaterial = material
        let node = SCNNode(geometry: box)
        node.position = position
        node.castsShadow = true
        // Physics
        let shape = SCNPhysicsShape(geometry: box, options: nil)
        node.physicsBody = SCNPhysicsBody(type: .static, shape: shape)
        node.physicsBody?.categoryBitMask = PhysicsCategory.wall
        node.physicsBody?.collisionBitMask = PhysicsCategory.player | PhysicsCategory.bullet
        parent.addChildNode(node)
        return node
    }

    private static func crateCluster(root: SCNNode, center: SCNVector3, mat: SCNMaterial) {
        let sizes: [(SCNVector3, SCNVector3)] = [
            (SCNVector3(1.5, 1.5, 1.5), SCNVector3(center.x, 0.75, center.z)),
            (SCNVector3(1.5, 1.5, 1.5), SCNVector3(center.x + 1.6, 0.75, center.z)),
            (SCNVector3(1.5, 1.5, 1.5), SCNVector3(center.x, 0.75, center.z + 1.6)),
            (SCNVector3(1.5, 3.0, 1.5), SCNVector3(center.x + 1.6, 1.5, center.z + 1.6)),
            (SCNVector3(1.5, 1.5, 1.5), SCNVector3(center.x, 2.25, center.z))
        ]
        for (s, p) in sizes { addBox(to: root, size: s, position: p, material: mat) }
    }

    private static func officePartitions(root: SCNNode, mat: SCNMaterial) {
        let configs: [(SCNVector3, SCNVector3)] = [
            (SCNVector3(15, 2, 0.2), SCNVector3(-20, 1, -20)),
            (SCNVector3(0.2, 2, 15), SCNVector3(-20, 1, -12)),
            (SCNVector3(15, 2, 0.2), SCNVector3(10, 1, -20)),
            (SCNVector3(0.2, 2, 15), SCNVector3(10, 1, -12)),
            (SCNVector3(20, 2, 0.2), SCNVector3(0, 1, 5)),
            (SCNVector3(0.2, 2, 20), SCNVector3(-15, 1, 18)),
            (SCNVector3(15, 2, 0.2), SCNVector3(20, 1, 20)),
            (SCNVector3(0.2, 2, 12), SCNVector3(28, 1, 26))
        ]
        for (s, p) in configs { addBox(to: root, size: s, position: p, material: mat) }
    }

    private static func officeFurniture(root: SCNNode, mat: SCNMaterial) {
        let desks: [SCNVector3] = [
            SCNVector3(-18, 0, -18), SCNVector3(-12, 0, -18),
            SCNVector3(12, 0, -18), SCNVector3(18, 0, -18),
            SCNVector3(-18, 0, 10), SCNVector3(-12, 0, 10),
            SCNVector3(12, 0, 18), SCNVector3(18, 0, 18),
            SCNVector3(0, 0, 25), SCNVector3(6, 0, 25)
        ]
        for pos in desks {
            addBox(to: root, size: SCNVector3(2.5, 0.8, 1.2),
                   position: SCNVector3(pos.x, 0.4, pos.z), material: mat)
        }
    }

    private static func rooftopProps(root: SCNNode) {
        let hvacMat = SCNMaterial.pbr(color: UIColor(red: 0.35, green: 0.35, blue: 0.38, alpha: 1),
                                       metalness: 0.5, roughness: 0.6)
        let hvacPositions: [SCNVector3] = [
            SCNVector3(-20, 0, -20), SCNVector3(20, 0, -20),
            SCNVector3(-20, 0, 20), SCNVector3(20, 0, 20),
            SCNVector3(0, 0, -25)
        ]
        for pos in hvacPositions {
            addBox(to: root, size: SCNVector3(4, 2, 3),
                   position: SCNVector3(pos.x, 1, pos.z), material: hvacMat)
            // Vent pipe
            addBox(to: root, size: SCNVector3(0.4, 1.5, 0.4),
                   position: SCNVector3(pos.x + 1.5, 2.75, pos.z), material: hvacMat)
        }

        // Water towers
        let tankMat = SCNMaterial.pbr(color: UIColor(red: 0.45, green: 0.38, blue: 0.28, alpha: 1),
                                       metalness: 0.1, roughness: 0.85)
        let tank = SCNCylinder(radius: 2, height: 3)
        tank.firstMaterial = tankMat
        let tankNode = SCNNode(geometry: tank)
        tankNode.position = SCNVector3(-28, 1.5, -28)
        tankNode.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(geometry: tank))
        tankNode.physicsBody?.categoryBitMask = PhysicsCategory.wall
        root.addChildNode(tankNode)

        // Concrete barriers
        let barrierMat = SCNMaterial.pbr(color: UIColor(red: 0.5, green: 0.48, blue: 0.45, alpha: 1),
                                          roughness: 0.9)
        let barrierPositions: [SCNVector3] = [
            SCNVector3(10, 0, 10), SCNVector3(-10, 0, 10),
            SCNVector3(10, 0, -10), SCNVector3(-10, 0, -10)
        ]
        for pos in barrierPositions {
            addBox(to: root, size: SCNVector3(3, 1.2, 0.5),
                   position: SCNVector3(pos.x, 0.6, pos.z), material: barrierMat)
        }
    }

    // MARK: - Lighting

    private static func addWarehouseLights(to root: SCNNode) {
        let lightPositions: [SCNVector3] = [
            SCNVector3(-15, 5.5, -15), SCNVector3(15, 5.5, -15),
            SCNVector3(-15, 5.5, 15), SCNVector3(15, 5.5, 15),
            SCNVector3(0, 5.5, 0)
        ]
        for pos in lightPositions {
            let light = SCNLight()
            light.type = .omni
            light.color = UIColor(red: 1.0, green: 0.9, blue: 0.7, alpha: 1)
            light.intensity = 600
            light.attenuationStartDistance = 2
            light.attenuationEndDistance = 20
            light.castsShadow = true
            light.shadowMode = .deferred
            light.shadowSampleCount = 4
            let node = SCNNode(); node.light = light; node.position = pos
            root.addChildNode(node)

            // Hanging lamp mesh
            let lampBox = SCNBox(width: 0.6, height: 0.15, length: 0.6, chamferRadius: 0.02)
            lampBox.firstMaterial = SCNMaterial.pbr(color: .white,
                                                     emission: UIColor(red: 1, green: 0.95, blue: 0.7, alpha: 1))
            let lampNode = SCNNode(geometry: lampBox)
            lampNode.position = pos
            root.addChildNode(lampNode)
        }
    }

    private static func officeLights(root: SCNNode) {
        let cols: [Float] = [-25, -10, 5, 20]
        let rows: [Float] = [-25, 0, 25]
        for x in cols {
            for z in rows {
                let light = SCNLight()
                light.type = .omni
                light.color = UIColor(red: 0.9, green: 0.95, blue: 1.0, alpha: 1)
                light.intensity = 500
                light.attenuationStartDistance = 1
                light.attenuationEndDistance = 18
                let n = SCNNode(); n.light = light
                n.position = SCNVector3(x, 3.5, z)
                root.addChildNode(n)
            }
        }
    }

    private static func rooftopSearchlights(root: SCNNode) {
        for i in 0..<4 {
            let angle = Float(i) * Float.pi / 2
            let x = cos(angle) * 28
            let z = sin(angle) * 28
            let light = SCNLight()
            light.type = .spot
            light.color = UIColor(red: 0.8, green: 0.8, blue: 1.0, alpha: 1)
            light.intensity = 800
            light.spotInnerAngle = 10
            light.spotOuterAngle = 25
            light.castsShadow = false
            let n = SCNNode(); n.light = light
            n.position = SCNVector3(x, 5, z)
            n.look(at: SCNVector3(0, 0, 0))

            let rotation = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 6)
            let pivot = SCNNode(); pivot.position = .init(0, 0, 0)
            pivot.addChildNode(n)
            root.addChildNode(pivot)
            pivot.runAction(.repeatForever(rotation))
        }
    }

    // MARK: - Enemy Spawning

    private static func spawnEnemies(root: SCNNode,
                                      positions: [SCNVector3],
                                      level: Int) -> [EnemyNode] {
        return positions.map { pos in
            let enemy = EnemyNode(level: level)
            enemy.position = pos
            root.addChildNode(enemy)
            return enemy
        }
    }
}

// MARK: - Physics Categories

struct PhysicsCategory {
    static let none:   Int = 0
    static let player: Int = 1 << 0
    static let enemy:  Int = 1 << 1
    static let bullet: Int = 1 << 2
    static let wall:   Int = 1 << 3
}
