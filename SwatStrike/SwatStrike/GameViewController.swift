import UIKit
import SceneKit
import AVFoundation

final class GameViewController: UIViewController {

    // MARK: - Properties

    private let levelIndex: Int
    private var scnView: SCNView!
    private var scene: SCNScene!
    private var hud: HUDView!

    // Player
    private let playerNode = SCNNode()
    private let cameraNode = SCNNode()

    // Game state
    private var enemies: [EnemyNode] = []
    private var lastUpdateTime: TimeInterval = 0
    private var lastFireTime: TimeInterval = 0
    private var isFiring: Bool = false

    // Movement
    private var moveVector: CGVector = .zero
    private var lookDelta: CGVector = .zero

    // Camera smoothing
    private var cameraYaw: Float = 0
    private var cameraPitch: Float = 0
    private let pitchLimit: Float = Float.pi / 3

    // Weapon gun model node
    private let gunNode = SCNNode()
    private var muzzleFlashNode: SCNNode?

    // Audio
    private var audioPlayers: [String: AVAudioPlayer] = [:]

    // MARK: - Init

    init(level: Int) {
        self.levelIndex = level
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        GameState.shared.reset(for: levelIndex)
        setupScene()
        setupPlayer()
        buildLevel()
        setupGunModel()
        setupHUD()
        setupAudio()
        showLevelIntro()
    }

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }

    // MARK: - Scene Setup

    private func setupScene() {
        scene = SCNScene()

        scnView = SCNView(frame: view.bounds)
        scnView.scene = scene
        scnView.delegate = self
        scnView.isPlaying = true
        scnView.showsStatistics = false
        scnView.antialiasingMode = .multisampling4X
        scnView.autoenablesDefaultLighting = false
        scnView.backgroundColor = .black

        // Post-processing: bloom via technique
        if let url = Bundle.main.url(forResource: "PostProcess", withExtension: "plist"),
           let technique = SCNTechnique(dictionary: NSDictionary(contentsOf: url) as? [String: Any] ?? [:]) {
            scnView.technique = technique
        }

        scnView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(scnView)
    }

    private func setupPlayer() {
        // Camera
        let camera = SCNCamera()
        camera.fieldOfView = 80
        camera.zNear = 0.1
        camera.zFar = 200
        camera.motionBlurIntensity = 0.3
        camera.wantsDepthOfField = false
        camera.bloomIntensity = 0.4
        camera.bloomThreshold = 0.8
        camera.bloomBlurRadius = 8
        camera.contrast = 0.1
        camera.saturation = 1.1

        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0.15, 0)

        playerNode.addChildNode(cameraNode)
        playerNode.position = SCNVector3(0, 1.7, 0)
        scene.rootNode.addChildNode(playerNode)

        scnView.pointOfView = cameraNode

        // Player physics
        let capsule = SCNCapsule(capRadius: 0.35, height: 1.7)
        let shape = SCNPhysicsShape(geometry: capsule, options: nil)
        playerNode.physicsBody = SCNPhysicsBody(type: .kinematic, shape: shape)
        playerNode.physicsBody?.categoryBitMask = PhysicsCategory.player
        playerNode.physicsBody?.collisionBitMask = PhysicsCategory.wall | PhysicsCategory.enemy
        playerNode.physicsBody?.contactTestBitMask = PhysicsCategory.enemy
    }

    private func buildLevel() {
        enemies = LevelBuilder.build(level: levelIndex, scene: scene)
        GameState.shared.enemiesRemaining = enemies.count
        enemies.forEach { enemy in
            enemy.playerNode = playerNode
            enemy.onDeath = { [weak self] in
                DispatchQueue.main.async { self?.handleEnemyDeath(enemy) }
            }
            enemy.onDamagePlayer = { [weak self] damage in
                DispatchQueue.main.async { self?.playerTookDamage(damage) }
            }
        }
    }

    private func setupGunModel() {
        // M4A1 model built from geometry
        let bodyMat = SCNMaterial()
        bodyMat.lightingModel = .physicallyBased
        bodyMat.diffuse.contents = UIColor(white: 0.12, alpha: 1)
        bodyMat.metalness.contents = CGFloat(0.85)
        bodyMat.roughness.contents = CGFloat(0.3)

        // Receiver
        let receiver = SCNBox(width: 0.04, height: 0.035, length: 0.28, chamferRadius: 0.005)
        receiver.firstMaterial = bodyMat
        let receiverNode = SCNNode(geometry: receiver)

        // Barrel
        let barrel = SCNCylinder(radius: 0.008, height: 0.22)
        barrel.firstMaterial = bodyMat
        let barrelNode = SCNNode(geometry: barrel)
        barrelNode.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        barrelNode.position = SCNVector3(0, 0, -0.25)

        // Magazine
        let mag = SCNBox(width: 0.025, height: 0.06, length: 0.04, chamferRadius: 0.003)
        mag.firstMaterial = bodyMat
        let magNode = SCNNode(geometry: mag)
        magNode.position = SCNVector3(0, -0.045, -0.03)

        // Stock
        let stock = SCNBox(width: 0.025, height: 0.03, length: 0.12, chamferRadius: 0.005)
        stock.firstMaterial = bodyMat
        let stockNode = SCNNode(geometry: stock)
        stockNode.position = SCNVector3(0, -0.005, 0.2)

        // Scope
        let scopeMat = SCNMaterial()
        scopeMat.lightingModel = .physicallyBased
        scopeMat.diffuse.contents = UIColor(white: 0.08, alpha: 1)
        scopeMat.metalness.contents = CGFloat(0.9)
        scopeMat.roughness.contents = CGFloat(0.2)
        let scope = SCNCylinder(radius: 0.012, height: 0.1)
        scope.firstMaterial = scopeMat
        let scopeNode = SCNNode(geometry: scope)
        scopeNode.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        scopeNode.position = SCNVector3(0, 0.025, -0.05)

        gunNode.addChildNode(receiverNode)
        gunNode.addChildNode(barrelNode)
        gunNode.addChildNode(magNode)
        gunNode.addChildNode(stockNode)
        gunNode.addChildNode(scopeNode)

        // Position gun in camera view (lower-right)
        gunNode.position = SCNVector3(0.12, -0.09, -0.35)
        gunNode.eulerAngles = SCNVector3(0, 0, 0)

        // Muzzle flash attachment point
        let muzzlePos = SCNNode()
        muzzlePos.position = SCNVector3(0, 0, -0.36)
        muzzlePos.name = "muzzlePoint"
        gunNode.addChildNode(muzzlePos)

        cameraNode.addChildNode(gunNode)

        // Idle sway animation
        let sway = SCNAction.sequence([
            .move(by: SCNVector3(0.003, 0.002, 0), duration: 1.5),
            .move(by: SCNVector3(-0.003, -0.002, 0), duration: 1.5)
        ])
        gunNode.runAction(.repeatForever(sway))
    }

    private func setupHUD() {
        hud = HUDView(frame: view.bounds)
        hud.delegate = self
        hud.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(hud)
        hud.updateLevel(levelIndex)
        hud.updateEnemyCount(enemies.count)
        hud.updateAmmo(inMag: GameState.shared.ammoInMag,
                       reserve: GameState.shared.reserveAmmo,
                       reloading: false)
        hud.updateWeapon(GameState.shared.currentWeapon.name)
        hud.updateHealth(GameState.shared.playerHealth, max: GameState.shared.maxHealth)
    }

    private func setupAudio() {
        // Pre-warm audio session
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    // MARK: - Shooting

    private func fireWeapon() {
        let state = GameState.shared
        guard state.canFire() else {
            if state.ammoInMag == 0 && !state.isReloading {
                triggerReload()
            }
            return
        }

        let now = CACurrentMediaTime()
        guard now - lastFireTime >= state.currentWeapon.fireRate else { return }
        lastFireTime = now

        state.consumeAmmo()
        hud.updateAmmo(inMag: state.ammoInMag, reserve: state.reserveAmmo, reloading: false)

        // Muzzle flash
        showMuzzleFlash()

        // Recoil animation
        applyRecoil()

        // Crosshair spread
        hud.setCrosshairSpread(CGFloat(state.currentWeapon.spread * 20))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.hud.setCrosshairSpread(0)
        }

        // Raycasts for each pellet
        let pellets = state.currentWeapon.pellets
        let spread = state.currentWeapon.spread
        let range = state.currentWeapon.range

        for _ in 0..<pellets {
            let sx = Float.random(in: -spread...spread)
            let sy = Float.random(in: -spread...spread)
            performRaycast(spreadX: sx, spreadY: sy, range: range, damage: state.currentWeapon.damage)
        }

        // Auto-reload when empty
        if state.ammoInMag == 0 && state.reserveAmmo > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.triggerReload()
            }
        }
    }

    private func performRaycast(spreadX: Float, spreadY: Float, range: Float, damage: Float) {
        // Build ray from camera center + spread
        guard let pov = scnView.pointOfView else { return }
        let camTransform = pov.worldTransform

        let forward = SCNVector3(-camTransform.m31 + spreadX,
                                  -camTransform.m32 + spreadY,
                                  -camTransform.m33)
        let len = sqrt(forward.x * forward.x + forward.y * forward.y + forward.z * forward.z)
        let dir = SCNVector3(forward.x / len, forward.y / len, forward.z / len)

        let origin = SCNVector3(camTransform.m41, camTransform.m42, camTransform.m43)
        let end = SCNVector3(origin.x + dir.x * range,
                              origin.y + dir.y * range,
                              origin.z + dir.z * range)

        let hits = scene.physicsWorld.rayTestWithSegment(from: origin,
                                                          to: end,
                                                          options: [
                                                            .searchMode: SCNPhysicsWorld.TestSearchMode.closest,
                                                            .collisionBitMask: PhysicsCategory.enemy | PhysicsCategory.wall
                                                          ])

        guard let hit = hits.first else { return }

        let hitPos = hit.worldCoordinates

        if let enemyNode = hit.node.parent as? EnemyNode ?? hit.node as? EnemyNode {
            // Hit enemy
            enemyNode.takeDamage(damage)
            hud.crosshairHit()
            ParticleEffects.bloodSplatter(at: hitPos, in: scene)
            let screenPt = scnView.projectPoint(hitPos)
            hud.showDamageNumber(damage, at: CGPoint(x: CGFloat(screenPt.x), y: CGFloat(screenPt.y)))
        } else {
            // Hit wall
            ParticleEffects.bulletImpact(at: hitPos, in: scene)
        }
    }

    private func showMuzzleFlash() {
        if let mp = gunNode.childNode(withName: "muzzlePoint", recursively: false) {
            let ps = ParticleEffects.muzzleFlash()
            let flashNode = SCNNode()
            flashNode.position = mp.worldPosition
            scene.rootNode.addChildNode(flashNode)
            flashNode.addParticleSystem(ps)
            flashNode.runAction(.sequence([.wait(duration: 0.1), .removeFromParentNode()]))

            // Muzzle light flash
            let light = SCNLight()
            light.type = .omni
            light.color = UIColor(red: 1, green: 0.85, blue: 0.3, alpha: 1)
            light.intensity = 800
            light.attenuationEndDistance = 5
            let lightNode = SCNNode(); lightNode.light = light
            lightNode.position = mp.worldPosition
            scene.rootNode.addChildNode(lightNode)
            lightNode.runAction(.sequence([.wait(duration: 0.04), .removeFromParentNode()]))
        }
    }

    private func applyRecoil() {
        let recoilUp = SCNAction.rotateBy(x: CGFloat(-Float.pi / 180 * 3), y: 0, z: 0, duration: 0.04)
        let recoilDown = SCNAction.rotateBy(x: CGFloat(Float.pi / 180 * 3), y: 0, z: 0, duration: 0.08)
        let recoilBack = SCNAction.moveBy(x: 0, y: 0, z: 0.02, duration: 0.04)
        let recoilForward = SCNAction.moveBy(x: 0, y: 0, z: -0.02, duration: 0.08)
        gunNode.runAction(.group([.sequence([recoilBack, recoilForward]),
                                   .sequence([recoilUp, recoilDown])]))
        cameraPitch += Float.pi / 180 * 1.5
    }

    private func triggerReload() {
        let state = GameState.shared
        guard !state.isReloading, state.reserveAmmo > 0, state.ammoInMag < state.currentWeapon.maxAmmo else { return }

        state.isReloading = true
        hud.updateAmmo(inMag: state.ammoInMag, reserve: state.reserveAmmo, reloading: true)

        // Reload animation
        let rotDown = SCNAction.rotateBy(x: CGFloat(Float.pi / 8), y: 0, z: CGFloat(Float.pi / 12), duration: 0.3)
        let wait = SCNAction.wait(duration: state.currentWeapon.reloadTime - 0.6)
        let rotUp = SCNAction.rotateBy(x: CGFloat(-Float.pi / 8), y: 0, z: CGFloat(-Float.pi / 12), duration: 0.3)
        gunNode.runAction(.sequence([rotDown, wait, rotUp]))

        DispatchQueue.main.asyncAfter(deadline: .now() + state.currentWeapon.reloadTime) { [weak self] in
            state.reload()
            state.isReloading = false
            self?.hud.updateAmmo(inMag: state.ammoInMag,
                                  reserve: state.reserveAmmo,
                                  reloading: false)
        }
    }

    // MARK: - Enemy Events

    private func handleEnemyDeath(_ enemy: EnemyNode) {
        let state = GameState.shared
        state.addKill()
        ParticleEffects.deathEffect(at: enemy.position, in: scene)
        hud.showKill(state.killCount)
        hud.updateEnemyCount(state.enemiesRemaining)

        if state.status == .levelComplete {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.showLevelComplete()
            }
        }
    }

    private func playerTookDamage(_ damage: Float) {
        guard GameState.shared.status == .playing else { return }
        GameState.shared.takeDamage(damage)
        hud.updateHealth(GameState.shared.playerHealth, max: GameState.shared.maxHealth)
        hud.showHitVignette()

        if GameState.shared.status == .gameOver {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.showGameOver()
            }
        }
    }

    // MARK: - UI Overlays

    private func showLevelIntro() {
        let overlay = UIView(frame: view.bounds)
        overlay.backgroundColor = .black
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(overlay)

        let lbl = UILabel()
        let names = ["", "MISSION 1\nWAREHOUSE", "MISSION 2\nOFFICE BUILDING", "MISSION 3\nROOFTOP SIEGE"]
        lbl.text = names[min(levelIndex, names.count - 1)]
        lbl.numberOfLines = 2
        lbl.font = UIFont(name: "AvenirNext-Heavy", size: 36) ??
                   UIFont.systemFont(ofSize: 36, weight: .black)
        lbl.textColor = .white
        lbl.textAlignment = .center
        lbl.translatesAutoresizingMaskIntoConstraints = false
        overlay.addSubview(lbl)
        NSLayoutConstraint.activate([
            lbl.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            lbl.centerYAnchor.constraint(equalTo: overlay.centerYAnchor)
        ])

        UIView.animate(withDuration: 0.5, delay: 1.5, options: .curveEaseIn) {
            overlay.alpha = 0
        } completion: { _ in
            overlay.removeFromSuperview()
        }
    }

    private func showLevelComplete() {
        GameState.shared.status = .levelComplete
        isFiring = false
        ParticleEffects.victory(in: scene)

        let vc = ResultViewController(won: true,
                                       score: GameState.shared.score,
                                       kills: GameState.shared.killCount,
                                       level: levelIndex)
        vc.modalPresentationStyle = .fullScreen
        vc.modalTransitionStyle = .crossDissolve
        present(vc, animated: true)
    }

    private func showGameOver() {
        isFiring = false
        let vc = ResultViewController(won: false,
                                       score: GameState.shared.score,
                                       kills: GameState.shared.killCount,
                                       level: levelIndex)
        vc.modalPresentationStyle = .fullScreen
        vc.modalTransitionStyle = .crossDissolve
        present(vc, animated: true)
    }

    // MARK: - Player Movement

    private func updatePlayerMovement(deltaTime: Float) {
        guard GameState.shared.status == .playing else { return }

        let state = GameState.shared

        // Look (yaw/pitch from accumulated delta)
        let lookSensitivity: Float = 0.003
        cameraYaw -= Float(lookDelta.dx) * lookSensitivity
        cameraPitch -= Float(lookDelta.dy) * lookSensitivity
        cameraPitch = max(-pitchLimit, min(pitchLimit, cameraPitch))

        // Decay look delta
        lookDelta = .zero

        playerNode.eulerAngles = SCNVector3(0, cameraYaw, 0)
        cameraNode.eulerAngles = SCNVector3(cameraPitch, 0, 0)

        // Move
        if moveVector != .zero {
            let speed: Float = 5.0
            let sinY = sin(cameraYaw)
            let cosY = cos(cameraYaw)
            let fx = Float(moveVector.dx) * cosY + Float(moveVector.dy) * sinY
            let fz = Float(moveVector.dx) * (-sinY) + Float(moveVector.dy) * cosY

            // Clamp to level bounds
            let newX = playerNode.position.x + fx * speed * deltaTime
            let newZ = playerNode.position.z + fz * speed * deltaTime
            let bound: Float = 28
            playerNode.position = SCNVector3(
                max(-bound, min(bound, newX)),
                playerNode.position.y,
                max(-bound, min(bound, newZ))
            )

            // Bob gun
            let bobT = CACurrentMediaTime()
            let bobY = Float(sin(bobT * 8)) * 0.003
            let bobX = Float(cos(bobT * 4)) * 0.002
            gunNode.position = SCNVector3(0.12 + bobX, -0.09 + bobY, -0.35)
        }
    }

    private func updateEnemyAI(deltaTime: TimeInterval, currentTime: TimeInterval) {
        guard GameState.shared.status == .playing else { return }
        for enemy in enemies where enemy.state != .dead {
            enemy.update(deltaTime: deltaTime, currentTime: currentTime)
        }
    }
}

// MARK: - SCNSceneRendererDelegate

extension GameViewController: SCNSceneRendererDelegate {
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        guard lastUpdateTime > 0 else { lastUpdateTime = time; return }
        let dt = min(Float(time - lastUpdateTime), 0.05)
        lastUpdateTime = time

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.updatePlayerMovement(deltaTime: dt)

            if self.isFiring {
                self.fireWeapon()
            }
        }
        updateEnemyAI(deltaTime: TimeInterval(dt), currentTime: time)
    }
}

// MARK: - HUDViewDelegate

extension GameViewController: HUDViewDelegate {
    func hudDidTapFire() { fireWeapon() }
    func hudFireBegan() { isFiring = true }
    func hudFireEnded() { isFiring = false }
    func hudDidTapReload() { triggerReload() }
    func hudJoystickChanged(_ vector: CGVector) { moveVector = vector }
    func hudLookChanged(_ delta: CGVector) { lookDelta = delta }

    func hudDidTapPause() {
        let isPaused = scnView.isPlaying == false
        scnView.isPlaying = isPaused
        if !isPaused {
            // Show pause menu
            let alert = UIAlertController(title: "PAUSED", message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Resume", style: .default) { [weak self] _ in
                self?.scnView.isPlaying = true
            })
            alert.addAction(UIAlertAction(title: "Main Menu", style: .destructive) { [weak self] _ in
                self?.dismiss(animated: true) {
                    self?.presentingViewController?.dismiss(animated: false)
                }
            })
            present(alert, animated: true)
        }
    }
}

// MARK: - ResultViewController

final class ResultViewController: UIViewController {
    private let won: Bool
    private let score: Int
    private let kills: Int
    private let level: Int

    init(won: Bool, score: Int, kills: Int, level: Int) {
        self.won = won; self.score = score; self.kills = kills; self.level = level
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    override var prefersStatusBarHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }

    private func setupUI() {
        let grad = CAGradientLayer()
        grad.colors = won
            ? [UIColor(red: 0, green: 0.15, blue: 0, alpha: 1).cgColor,
               UIColor(red: 0, green: 0.05, blue: 0, alpha: 1).cgColor]
            : [UIColor(red: 0.15, green: 0, blue: 0, alpha: 1).cgColor,
               UIColor(red: 0.05, green: 0, blue: 0, alpha: 1).cgColor]
        grad.frame = view.bounds
        view.layer.insertSublayer(grad, at: 0)

        let titleLbl = UILabel()
        titleLbl.text = won ? "MISSION\nCOMPLETE" : "YOU DIED"
        titleLbl.numberOfLines = 2
        titleLbl.textAlignment = .center
        titleLbl.font = UIFont(name: "AvenirNext-Heavy", size: 56) ??
                        UIFont.systemFont(ofSize: 56, weight: .black)
        titleLbl.textColor = won ? UIColor(red: 0.2, green: 1, blue: 0.3, alpha: 1)
                                 : UIColor(red: 1, green: 0.1, blue: 0.1, alpha: 1)
        titleLbl.layer.shadowColor = titleLbl.textColor.cgColor
        titleLbl.layer.shadowRadius = 20
        titleLbl.layer.shadowOpacity = 0.8
        titleLbl.layer.shadowOffset = .zero
        titleLbl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLbl)

        let statsLbl = UILabel()
        statsLbl.text = "SCORE: \(score)  |  KILLS: \(kills)"
        statsLbl.textAlignment = .center
        statsLbl.font = UIFont(name: "AvenirNext-Medium", size: 20) ??
                        UIFont.systemFont(ofSize: 20, weight: .medium)
        statsLbl.textColor = UIColor(white: 0.8, alpha: 1)
        statsLbl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statsLbl)

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        if won && level < 3 {
            let nextBtn = MenuButton(title: "NEXT LEVEL", style: .primary)
            nextBtn.addTarget(self, action: #selector(nextLevel), for: .touchUpInside)
            stack.addArrangedSubview(nextBtn)
            nextBtn.widthAnchor.constraint(equalToConstant: 180).isActive = true
            nextBtn.heightAnchor.constraint(equalToConstant: 52).isActive = true
        }

        let retryBtn = MenuButton(title: won ? "REPLAY" : "RETRY", style: .secondary)
        retryBtn.addTarget(self, action: #selector(retry), for: .touchUpInside)
        stack.addArrangedSubview(retryBtn)
        retryBtn.widthAnchor.constraint(equalToConstant: 160).isActive = true
        retryBtn.heightAnchor.constraint(equalToConstant: 52).isActive = true

        let menuBtn = MenuButton(title: "MAIN MENU", style: .secondary)
        menuBtn.addTarget(self, action: #selector(goMenu), for: .touchUpInside)
        stack.addArrangedSubview(menuBtn)
        menuBtn.widthAnchor.constraint(equalToConstant: 160).isActive = true
        menuBtn.heightAnchor.constraint(equalToConstant: 52).isActive = true

        NSLayoutConstraint.activate([
            titleLbl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLbl.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -80),

            statsLbl.topAnchor.constraint(equalTo: titleLbl.bottomAnchor, constant: 20),
            statsLbl.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            stack.topAnchor.constraint(equalTo: statsLbl.bottomAnchor, constant: 40),
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])

        titleLbl.alpha = 0
        UIView.animate(withDuration: 0.8, delay: 0.3) { titleLbl.alpha = 1 }
    }

    @objc private func nextLevel() {
        let next = GameViewController(level: level + 1)
        next.modalPresentationStyle = .fullScreen
        next.modalTransitionStyle = .crossDissolve
        // Dismiss result + game, then present new game
        presentingViewController?.dismiss(animated: false) {
            // Find top vc
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let root = windowScene.windows.first?.rootViewController {
                var top = root
                while let p = top.presentedViewController { top = p }
                let gameVC = GameViewController(level: self.level + 1)
                gameVC.modalPresentationStyle = .fullScreen
                gameVC.modalTransitionStyle = .crossDissolve
                top.present(gameVC, animated: true)
            }
        }
    }

    @objc private func retry() {
        presentingViewController?.dismiss(animated: false) {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let root = windowScene.windows.first?.rootViewController {
                var top = root
                while let p = top.presentedViewController { top = p }
                let gameVC = GameViewController(level: self.level)
                gameVC.modalPresentationStyle = .fullScreen
                gameVC.modalTransitionStyle = .crossDissolve
                top.present(gameVC, animated: true)
            }
        }
    }

    @objc private func goMenu() {
        // Unwind all presented VCs to root
        var vc: UIViewController? = self
        while let p = vc?.presentingViewController { vc = p }
        vc?.dismiss(animated: true)
    }
}
