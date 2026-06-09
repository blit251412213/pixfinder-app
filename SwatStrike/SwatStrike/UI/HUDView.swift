import UIKit

protocol HUDViewDelegate: AnyObject {
    func hudDidTapFire()
    func hudDidTapReload()
    func hudDidTapPause()
    func hudJoystickChanged(_ vector: CGVector)
    func hudLookChanged(_ delta: CGVector)
    func hudFireBegan()
    func hudFireEnded()
}

final class HUDView: UIView {

    weak var delegate: HUDViewDelegate?

    // MARK: - UI Elements

    // Health
    private let healthContainer = UIView()
    private let healthBarBg = UIView()
    private let healthBarFill = UIView()
    private let healthIcon = UILabel()
    private let healthLabel = UILabel()

    // Ammo
    private let ammoLabel = UILabel()
    private let weaponLabel = UILabel()
    private let reloadIndicator = UILabel()

    // Crosshair
    private let crosshairView = CrosshairView()

    // Kill feed
    private let killFeedLabel = UILabel()
    private var killFeedTimer: Timer?

    // Compass / level info
    private let levelLabel = UILabel()
    private let enemyCountLabel = UILabel()

    // Hit vignette
    private let vignetteView = UIView()
    private var vignetteTimer: Timer?

    // Joystick
    private let joystickBase = UIView()
    private let joystickThumb = UIView()
    private var joystickCenter: CGPoint = .zero
    private var joystickActive: Bool = false
    private var joystickTouch: UITouch?

    // Look area
    private var lookTouch: UITouch?
    private var lookLastPoint: CGPoint = .zero

    // Fire button
    private let fireButton = UIButton()
    private var fireTouch: UITouch?

    // Reload button
    private let reloadButton = UIButton()

    // Pause button
    private let pauseButton = UIButton()

    // Damage numbers
    private var damageLabels: [UILabel] = []

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = true
        isMultipleTouchEnabled = true
        backgroundColor = .clear
        setupHUD()
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Setup

    private func setupHUD() {
        setupVignette()
        setupHealthBar()
        setupAmmoDisplay()
        setupCrosshair()
        setupKillFeed()
        setupLevelInfo()
        setupJoystick()
        setupFireButton()
        setupReloadButton()
        setupPauseButton()
    }

    private func setupVignette() {
        vignetteView.backgroundColor = UIColor(red: 0.8, green: 0, blue: 0, alpha: 0)
        vignetteView.isUserInteractionEnabled = false
        vignetteView.layer.cornerRadius = 0
        addSubview(vignetteView)
        vignetteView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            vignetteView.topAnchor.constraint(equalTo: topAnchor),
            vignetteView.bottomAnchor.constraint(equalTo: bottomAnchor),
            vignetteView.leadingAnchor.constraint(equalTo: leadingAnchor),
            vignetteView.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    private func setupHealthBar() {
        healthIcon.text = "♥"
        healthIcon.font = UIFont.systemFont(ofSize: 16)
        healthIcon.textColor = UIColor(red: 1, green: 0.2, blue: 0.2, alpha: 1)

        healthBarBg.backgroundColor = UIColor(white: 0.15, alpha: 0.8)
        healthBarBg.layer.cornerRadius = 6
        healthBarBg.layer.borderWidth = 1
        healthBarBg.layer.borderColor = UIColor(white: 0.4, alpha: 0.5).cgColor

        healthBarFill.backgroundColor = UIColor(red: 0.1, green: 0.9, blue: 0.2, alpha: 1)
        healthBarFill.layer.cornerRadius = 5
        healthBarBg.addSubview(healthBarFill)

        healthLabel.font = UIFont(name: "AvenirNext-Heavy", size: 14) ??
                           UIFont.systemFont(ofSize: 14, weight: .bold)
        healthLabel.textColor = .white
        healthLabel.text = "100"

        let stack = UIStackView(arrangedSubviews: [healthIcon, healthBarBg, healthLabel])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
            healthBarBg.widthAnchor.constraint(equalToConstant: 120),
            healthBarBg.heightAnchor.constraint(equalToConstant: 12)
        ])

        healthContainer.translatesAutoresizingMaskIntoConstraints = false
    }

    private func setupAmmoDisplay() {
        ammoLabel.font = UIFont(name: "AvenirNext-Heavy", size: 36) ??
                         UIFont.systemFont(ofSize: 36, weight: .black)
        ammoLabel.textColor = .white
        ammoLabel.textAlignment = .right
        ammoLabel.text = "30 / 120"
        ammoLabel.layer.shadowColor = UIColor.black.cgColor
        ammoLabel.layer.shadowRadius = 4
        ammoLabel.layer.shadowOpacity = 0.8
        ammoLabel.layer.shadowOffset = CGSize(width: 1, height: 1)

        weaponLabel.font = UIFont(name: "AvenirNext-Medium", size: 12) ??
                           UIFont.systemFont(ofSize: 12, weight: .medium)
        weaponLabel.textColor = UIColor(red: 1, green: 0.7, blue: 0.2, alpha: 1)
        weaponLabel.textAlignment = .right
        weaponLabel.text = "M4A1"

        reloadIndicator.font = UIFont(name: "AvenirNext-Heavy", size: 14) ??
                                UIFont.systemFont(ofSize: 14, weight: .bold)
        reloadIndicator.textColor = UIColor(red: 1, green: 0.7, blue: 0, alpha: 1)
        reloadIndicator.textAlignment = .right
        reloadIndicator.text = "RELOADING..."
        reloadIndicator.isHidden = true

        [ammoLabel, weaponLabel, reloadIndicator].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }

        NSLayoutConstraint.activate([
            ammoLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            ammoLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),

            weaponLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            weaponLabel.bottomAnchor.constraint(equalTo: ammoLabel.topAnchor, constant: -4),

            reloadIndicator.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            reloadIndicator.bottomAnchor.constraint(equalTo: weaponLabel.topAnchor, constant: -4)
        ])
    }

    private func setupCrosshair() {
        crosshairView.translatesAutoresizingMaskIntoConstraints = false
        crosshairView.isUserInteractionEnabled = false
        addSubview(crosshairView)
        NSLayoutConstraint.activate([
            crosshairView.centerXAnchor.constraint(equalTo: centerXAnchor),
            crosshairView.centerYAnchor.constraint(equalTo: centerYAnchor),
            crosshairView.widthAnchor.constraint(equalToConstant: 40),
            crosshairView.heightAnchor.constraint(equalToConstant: 40)
        ])
    }

    private func setupKillFeed() {
        killFeedLabel.font = UIFont(name: "AvenirNext-Heavy", size: 15) ??
                             UIFont.systemFont(ofSize: 15, weight: .bold)
        killFeedLabel.textColor = UIColor(red: 1, green: 0.3, blue: 0, alpha: 1)
        killFeedLabel.textAlignment = .right
        killFeedLabel.alpha = 0
        killFeedLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(killFeedLabel)
        NSLayoutConstraint.activate([
            killFeedLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            killFeedLabel.topAnchor.constraint(equalTo: topAnchor, constant: 20)
        ])
    }

    private func setupLevelInfo() {
        levelLabel.font = UIFont(name: "AvenirNext-Heavy", size: 14) ??
                          UIFont.systemFont(ofSize: 14, weight: .bold)
        levelLabel.textColor = UIColor(white: 0.8, alpha: 0.9)
        levelLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(levelLabel)

        enemyCountLabel.font = UIFont(name: "AvenirNext-Medium", size: 13) ??
                               UIFont.systemFont(ofSize: 13, weight: .medium)
        enemyCountLabel.textColor = UIColor(red: 1, green: 0.4, blue: 0.1, alpha: 1)
        enemyCountLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(enemyCountLabel)

        NSLayoutConstraint.activate([
            levelLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            levelLabel.topAnchor.constraint(equalTo: topAnchor, constant: 20),

            enemyCountLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            enemyCountLabel.topAnchor.constraint(equalTo: levelLabel.bottomAnchor, constant: 4)
        ])
    }

    private func setupJoystick() {
        joystickBase.backgroundColor = UIColor(white: 1, alpha: 0.07)
        joystickBase.layer.cornerRadius = 55
        joystickBase.layer.borderWidth = 2
        joystickBase.layer.borderColor = UIColor(white: 1, alpha: 0.2).cgColor
        joystickBase.isUserInteractionEnabled = false
        joystickBase.frame = CGRect(x: 0, y: 0, width: 110, height: 110)

        joystickThumb.backgroundColor = UIColor(white: 1, alpha: 0.35)
        joystickThumb.layer.cornerRadius = 28
        joystickThumb.layer.borderWidth = 2
        joystickThumb.layer.borderColor = UIColor(red: 1, green: 0.5, blue: 0, alpha: 0.8).cgColor
        joystickThumb.isUserInteractionEnabled = false
        joystickThumb.frame = CGRect(x: 0, y: 0, width: 56, height: 56)

        addSubview(joystickBase)
        joystickBase.addSubview(joystickThumb)
        joystickBase.isHidden = true
    }

    private func setupFireButton() {
        fireButton.backgroundColor = UIColor(red: 1, green: 0.1, blue: 0.1, alpha: 0.25)
        fireButton.layer.cornerRadius = 40
        fireButton.layer.borderWidth = 3
        fireButton.layer.borderColor = UIColor(red: 1, green: 0.2, blue: 0.1, alpha: 0.7).cgColor
        fireButton.layer.shadowColor = UIColor.red.cgColor
        fireButton.layer.shadowRadius = 8
        fireButton.layer.shadowOpacity = 0.4
        fireButton.layer.shadowOffset = .zero

        let label = UILabel()
        label.text = "FIRE"
        label.font = UIFont(name: "AvenirNext-Heavy", size: 13) ??
                     UIFont.systemFont(ofSize: 13, weight: .black)
        label.textColor = .white
        label.isUserInteractionEnabled = false
        label.translatesAutoresizingMaskIntoConstraints = false
        fireButton.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: fireButton.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: fireButton.centerYAnchor)
        ])

        fireButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(fireButton)
        NSLayoutConstraint.activate([
            fireButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -30),
            fireButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -90),
            fireButton.widthAnchor.constraint(equalToConstant: 80),
            fireButton.heightAnchor.constraint(equalToConstant: 80)
        ])

        fireButton.addTarget(self, action: #selector(fireTapped), for: .touchUpInside)
    }

    private func setupReloadButton() {
        reloadButton.backgroundColor = UIColor(red: 0.2, green: 0.7, blue: 1, alpha: 0.2)
        reloadButton.layer.cornerRadius = 28
        reloadButton.layer.borderWidth = 2
        reloadButton.layer.borderColor = UIColor(red: 0.4, green: 0.8, blue: 1, alpha: 0.6).cgColor
        let label = UILabel()
        label.text = "↺"
        label.font = UIFont.systemFont(ofSize: 22)
        label.textColor = .white
        label.isUserInteractionEnabled = false
        label.translatesAutoresizingMaskIntoConstraints = false
        reloadButton.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: reloadButton.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: reloadButton.centerYAnchor)
        ])

        reloadButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(reloadButton)
        NSLayoutConstraint.activate([
            reloadButton.trailingAnchor.constraint(equalTo: fireButton.leadingAnchor, constant: -20),
            reloadButton.centerYAnchor.constraint(equalTo: fireButton.centerYAnchor),
            reloadButton.widthAnchor.constraint(equalToConstant: 56),
            reloadButton.heightAnchor.constraint(equalToConstant: 56)
        ])
        reloadButton.addTarget(self, action: #selector(reloadTapped), for: .touchUpInside)
    }

    private func setupPauseButton() {
        pauseButton.setTitle("⏸", for: .normal)
        pauseButton.titleLabel?.font = UIFont.systemFont(ofSize: 20)
        pauseButton.backgroundColor = UIColor(white: 0, alpha: 0.4)
        pauseButton.layer.cornerRadius = 20
        pauseButton.layer.borderWidth = 1
        pauseButton.layer.borderColor = UIColor(white: 1, alpha: 0.3).cgColor
        pauseButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(pauseButton)
        NSLayoutConstraint.activate([
            pauseButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            pauseButton.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            pauseButton.widthAnchor.constraint(equalToConstant: 40),
            pauseButton.heightAnchor.constraint(equalToConstant: 40)
        ])
        pauseButton.addTarget(self, action: #selector(pauseTapped), for: .touchUpInside)
    }

    // MARK: - Update Methods

    func updateHealth(_ health: Float, max: Float) {
        let ratio = CGFloat(health / max)
        let totalWidth = healthBarBg.bounds.width > 0 ? healthBarBg.bounds.width : 120

        UIView.animate(withDuration: 0.15) {
            self.healthBarFill.frame = CGRect(x: 2, y: 2, width: (totalWidth - 4) * ratio, height: self.healthBarBg.bounds.height - 4)
        }
        healthLabel.text = "\(Int(health))"

        let r: CGFloat = ratio < 0.5 ? 1 : (1 - ratio) * 2
        let g: CGFloat = ratio > 0.5 ? 1 : ratio * 2
        healthBarFill.backgroundColor = UIColor(red: r, green: g, blue: 0, alpha: 1)
    }

    func updateAmmo(inMag: Int, reserve: Int, reloading: Bool) {
        ammoLabel.text = "\(inMag) / \(reserve)"
        reloadIndicator.isHidden = !reloading
        if inMag == 0 && !reloading {
            ammoLabel.textColor = UIColor(red: 1, green: 0.2, blue: 0.2, alpha: 1)
        } else {
            ammoLabel.textColor = .white
        }
    }

    func updateWeapon(_ name: String) {
        weaponLabel.text = name
    }

    func updateEnemyCount(_ count: Int) {
        enemyCountLabel.text = "ENEMIES: \(count)"
        if count == 0 {
            enemyCountLabel.textColor = UIColor(red: 0.2, green: 1, blue: 0.2, alpha: 1)
        }
    }

    func updateLevel(_ level: Int) {
        let names = ["", "WAREHOUSE", "OFFICE BUILDING", "ROOFTOP SIEGE"]
        levelLabel.text = "LEVEL \(level): \(names[min(level, names.count - 1)])"
    }

    func showKill(_ count: Int) {
        killFeedLabel.text = "ENEMY DOWN  +100  [\(count) kills]"
        killFeedTimer?.invalidate()
        killFeedLabel.alpha = 1
        killFeedTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            UIView.animate(withDuration: 0.5) { self?.killFeedLabel.alpha = 0 }
        }
    }

    func showHitVignette() {
        vignetteTimer?.invalidate()
        vignetteView.backgroundColor = UIColor(red: 0.8, green: 0, blue: 0, alpha: 0.35)
        vignetteTimer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: false) { [weak self] _ in
            UIView.animate(withDuration: 0.3) {
                self?.vignetteView.backgroundColor = UIColor(red: 0.8, green: 0, blue: 0, alpha: 0)
            }
        }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    func crosshairHit() {
        crosshairView.flashRed()
    }

    func showDamageNumber(_ amount: Float, at point: CGPoint) {
        let lbl = UILabel()
        lbl.text = "-\(Int(amount))"
        lbl.font = UIFont(name: "AvenirNext-Heavy", size: 20) ??
                   UIFont.systemFont(ofSize: 20, weight: .black)
        lbl.textColor = UIColor(red: 1, green: 0.9, blue: 0, alpha: 1)
        lbl.layer.shadowColor = UIColor.black.cgColor
        lbl.layer.shadowRadius = 3
        lbl.layer.shadowOpacity = 1
        lbl.sizeToFit()
        lbl.center = point
        addSubview(lbl)

        UIView.animate(withDuration: 0.8, delay: 0, options: .curveEaseOut) {
            lbl.center = CGPoint(x: point.x + CGFloat.random(in: -20...20),
                                 y: point.y - 60)
            lbl.alpha = 0
        } completion: { _ in
            lbl.removeFromSuperview()
        }
    }

    // MARK: - Crosshair spread

    func setCrosshairSpread(_ spread: CGFloat) {
        crosshairView.spread = spread
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let pt = touch.location(in: self)

            // Fire button handled by UIButton target
            if fireButton.frame.contains(pt) { continue }
            if reloadButton.frame.contains(pt) { continue }
            if pauseButton.frame.contains(pt) { continue }

            // Left half → joystick
            if pt.x < bounds.midX * 1.2 && joystickTouch == nil {
                joystickTouch = touch
                joystickCenter = pt
                joystickBase.isHidden = false
                joystickBase.center = pt
                joystickThumb.center = CGPoint(x: 55, y: 55)
                joystickActive = true
            }
            // Right half → look / auto-fire
            else if pt.x >= bounds.midX * 0.8 && lookTouch == nil {
                lookTouch = touch
                lookLastPoint = pt
                delegate?.hudFireBegan()
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if touch == joystickTouch {
                let pt = touch.location(in: self)
                let dx = pt.x - joystickCenter.x
                let dy = pt.y - joystickCenter.y
                let maxR: CGFloat = 50
                let dist = sqrt(dx * dx + dy * dy)
                let clampedDist = min(dist, maxR)
                let angle = atan2(dy, dx)
                let thumbX = 55 + cos(angle) * clampedDist
                let thumbY = 55 + sin(angle) * clampedDist
                joystickThumb.center = CGPoint(x: thumbX, y: thumbY)
                let nx = cos(angle) * (clampedDist / maxR)
                let ny = sin(angle) * (clampedDist / maxR)
                delegate?.hudJoystickChanged(CGVector(dx: nx, dy: ny))
            } else if touch == lookTouch {
                let pt = touch.location(in: self)
                let dx = pt.x - lookLastPoint.x
                let dy = pt.y - lookLastPoint.y
                lookLastPoint = pt
                delegate?.hudLookChanged(CGVector(dx: dx, dy: dy))
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if touch == joystickTouch {
                joystickTouch = nil
                joystickActive = false
                joystickBase.isHidden = true
                delegate?.hudJoystickChanged(.zero)
            } else if touch == lookTouch {
                lookTouch = nil
                delegate?.hudFireEnded()
            }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    // MARK: - Button Targets

    @objc private func fireTapped() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        delegate?.hudDidTapFire()
    }
    @objc private func reloadTapped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        delegate?.hudDidTapReload()
    }
    @objc private func pauseTapped() {
        delegate?.hudDidTapPause()
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        // Keep healthBarFill properly sized after layout
        let ratio = CGFloat(GameState.shared.playerHealth / GameState.shared.maxHealth)
        let w = healthBarBg.bounds.width
        healthBarFill.frame = CGRect(x: 2, y: 2, width: max(0, (w - 4) * ratio), height: healthBarBg.bounds.height - 4)
    }
}

// MARK: - CrosshairView

final class CrosshairView: UIView {

    var spread: CGFloat = 0 {
        didSet { setNeedsDisplay() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let cx = rect.midX
        let cy = rect.midY
        let gap: CGFloat = 4 + spread * 20
        let len: CGFloat = 8
        let thickness: CGFloat = 2

        ctx.setStrokeColor(UIColor.white.cgColor)
        ctx.setLineWidth(thickness)

        // Top
        ctx.move(to: CGPoint(x: cx, y: cy - gap - len))
        ctx.addLine(to: CGPoint(x: cx, y: cy - gap))
        // Bottom
        ctx.move(to: CGPoint(x: cx, y: cy + gap))
        ctx.addLine(to: CGPoint(x: cx, y: cy + gap + len))
        // Left
        ctx.move(to: CGPoint(x: cx - gap - len, y: cy))
        ctx.addLine(to: CGPoint(x: cx - gap, y: cy))
        // Right
        ctx.move(to: CGPoint(x: cx + gap, y: cy))
        ctx.addLine(to: CGPoint(x: cx + gap + len, y: cy))

        ctx.strokePath()

        // Center dot
        ctx.setFillColor(UIColor(white: 1, alpha: 0.8).cgColor)
        ctx.fillEllipse(in: CGRect(x: cx - 1.5, y: cy - 1.5, width: 3, height: 3))
    }

    func flashRed() {
        let orig = backgroundColor
        UIView.animate(withDuration: 0.05) {
            self.tintColor = .red
            self.alpha = 0.5
        } completion: { _ in
            UIView.animate(withDuration: 0.1) {
                self.alpha = 1.0
            }
        }
        _ = orig
    }
}
