import UIKit

final class MainMenuViewController: UIViewController {

    // MARK: - Subviews

    private let backgroundGradient = CAGradientLayer()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text = "SWAT\nSTRIKE"
        l.numberOfLines = 2
        l.textAlignment = .center
        l.font = UIFont(name: "AvenirNext-Heavy", size: 64) ??
                 UIFont.systemFont(ofSize: 64, weight: .black)
        l.textColor = .white
        l.layer.shadowColor = UIColor(red: 1, green: 0.3, blue: 0, alpha: 1).cgColor
        l.layer.shadowRadius = 20
        l.layer.shadowOpacity = 0.9
        l.layer.shadowOffset = .zero
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.text = "TACTICAL FPS"
        l.textAlignment = .center
        l.font = UIFont(name: "AvenirNext-Medium", size: 18) ??
                 UIFont.systemFont(ofSize: 18, weight: .medium)
        l.textColor = UIColor(red: 1, green: 0.6, blue: 0, alpha: 1)
        l.letterSpacing(12)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let playButton = MenuButton(title: "PLAY", style: .primary)
    private let howToButton = MenuButton(title: "HOW TO PLAY", style: .secondary)

    private let versionLabel: UILabel = {
        let l = UILabel()
        l.text = "v1.0"
        l.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        l.textColor = UIColor.white.withAlphaComponent(0.3)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupBackground()
        setupViews()
        setupConstraints()
        setupActions()
        animateTitle()
    }

    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }

    // MARK: - Setup

    private func setupBackground() {
        backgroundGradient.colors = [
            UIColor(red: 0.04, green: 0.04, blue: 0.08, alpha: 1).cgColor,
            UIColor(red: 0.08, green: 0.05, blue: 0.02, alpha: 1).cgColor,
            UIColor(red: 0.12, green: 0.06, blue: 0.0, alpha: 1).cgColor
        ]
        backgroundGradient.locations = [0, 0.5, 1]
        backgroundGradient.frame = view.bounds
        view.layer.insertSublayer(backgroundGradient, at: 0)

        // Tactical grid overlay
        let gridView = TacticalGridView()
        gridView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(gridView)
        NSLayoutConstraint.activate([
            gridView.topAnchor.constraint(equalTo: view.topAnchor),
            gridView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            gridView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            gridView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    private func setupViews() {
        [titleLabel, subtitleLabel, playButton, howToButton, versionLabel].forEach {
            view.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -100),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            playButton.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 50),
            playButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            playButton.widthAnchor.constraint(equalToConstant: 220),
            playButton.heightAnchor.constraint(equalToConstant: 56),

            howToButton.topAnchor.constraint(equalTo: playButton.bottomAnchor, constant: 16),
            howToButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            howToButton.widthAnchor.constraint(equalToConstant: 220),
            howToButton.heightAnchor.constraint(equalToConstant: 56),

            versionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            versionLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20)
        ])
    }

    private func setupActions() {
        playButton.addTarget(self, action: #selector(startGame), for: .touchUpInside)
        howToButton.addTarget(self, action: #selector(showHowTo), for: .touchUpInside)
    }

    private func animateTitle() {
        titleLabel.alpha = 0
        subtitleLabel.alpha = 0
        playButton.alpha = 0
        howToButton.alpha = 0

        UIView.animate(withDuration: 1.0, delay: 0.2, options: .curveEaseOut) {
            self.titleLabel.alpha = 1
        }
        UIView.animate(withDuration: 0.8, delay: 0.6, options: .curveEaseOut) {
            self.subtitleLabel.alpha = 1
        }
        UIView.animate(withDuration: 0.8, delay: 0.9, options: .curveEaseOut) {
            self.playButton.alpha = 1
        }
        UIView.animate(withDuration: 0.8, delay: 1.1, options: .curveEaseOut) {
            self.howToButton.alpha = 1
        }

        // Pulse title shadow
        let pulse = CABasicAnimation(keyPath: "shadowRadius")
        pulse.fromValue = 10
        pulse.toValue = 30
        pulse.duration = 1.5
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        titleLabel.layer.add(pulse, forKey: "shadowPulse")
    }

    // MARK: - Actions

    @objc private func startGame() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        let levelSelect = LevelSelectViewController()
        levelSelect.modalPresentationStyle = .fullScreen
        levelSelect.modalTransitionStyle = .crossDissolve
        present(levelSelect, animated: true)
    }

    @objc private func showHowTo() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let alert = UIAlertController(title: "HOW TO PLAY",
                                      message: """
LEFT JOYSTICK — Move
RIGHT DRAG — Aim / Look
FIRE button — Shoot
RELOAD button — Reload weapon

Eliminate all enemies to complete each level.
Watch your health and ammo!
""",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "READY", style: .default))
        present(alert, animated: true)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        backgroundGradient.frame = view.bounds
    }
}

// MARK: - MenuButton

final class MenuButton: UIButton {
    enum Style { case primary, secondary }

    private let style: Style

    init(title: String, style: Style) {
        self.style = style
        super.init(frame: .zero)
        setTitle(title, for: .normal)
        titleLabel?.font = UIFont(name: "AvenirNext-Heavy", size: 16) ??
                           UIFont.systemFont(ofSize: 16, weight: .black)
        layer.cornerRadius = 8
        layer.borderWidth = 2
        configure()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func configure() {
        switch style {
        case .primary:
            backgroundColor = UIColor(red: 1, green: 0.35, blue: 0, alpha: 1)
            setTitleColor(.white, for: .normal)
            layer.borderColor = UIColor(red: 1, green: 0.6, blue: 0.2, alpha: 1).cgColor
            layer.shadowColor = UIColor(red: 1, green: 0.35, blue: 0, alpha: 1).cgColor
            layer.shadowRadius = 12
            layer.shadowOpacity = 0.8
            layer.shadowOffset = .zero
        case .secondary:
            backgroundColor = UIColor.white.withAlphaComponent(0.08)
            setTitleColor(UIColor(red: 1, green: 0.6, blue: 0.2, alpha: 1), for: .normal)
            layer.borderColor = UIColor(red: 1, green: 0.6, blue: 0.2, alpha: 0.5).cgColor
        }
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.1) {
                self.transform = self.isHighlighted ?
                    CGAffineTransform(scaleX: 0.96, y: 0.96) : .identity
                self.alpha = self.isHighlighted ? 0.8 : 1.0
            }
        }
    }
}

// MARK: - LevelSelectViewController

final class LevelSelectViewController: UIViewController {

    private let backgroundGradient = CAGradientLayer()

    override func viewDidLoad() {
        super.viewDidLoad()
        backgroundGradient.colors = [
            UIColor(red: 0.04, green: 0.04, blue: 0.08, alpha: 1).cgColor,
            UIColor(red: 0.08, green: 0.05, blue: 0.02, alpha: 1).cgColor
        ]
        backgroundGradient.frame = view.bounds
        view.layer.insertSublayer(backgroundGradient, at: 0)
        setupUI()
    }

    override var prefersStatusBarHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }

    private func setupUI() {
        let title = UILabel()
        title.text = "SELECT MISSION"
        title.font = UIFont(name: "AvenirNext-Heavy", size: 32) ??
                     UIFont.systemFont(ofSize: 32, weight: .black)
        title.textColor = .white
        title.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(title)

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        let levels: [(Int, String, String, UIColor)] = [
            (1, "WAREHOUSE", "12 Enemies", UIColor(red: 0.2, green: 0.6, blue: 1, alpha: 1)),
            (2, "OFFICE\nBUILDING", "20 Enemies", UIColor(red: 1, green: 0.5, blue: 0, alpha: 1)),
            (3, "ROOFTOP\nSIEGE", "30 Enemies", UIColor(red: 1, green: 0.1, blue: 0.1, alpha: 1))
        ]

        for (index, name, enemyCount, color) in levels {
            let card = LevelCard(level: index, name: name, enemyCount: enemyCount, color: color)
            card.addTarget(self, action: #selector(levelTapped(_:)), for: .touchUpInside)
            card.tag = index
            stack.addArrangedSubview(card)
            card.widthAnchor.constraint(equalToConstant: 200).isActive = true
            card.heightAnchor.constraint(equalToConstant: 260).isActive = true
        }

        let backBtn = MenuButton(title: "← BACK", style: .secondary)
        backBtn.translatesAutoresizingMaskIntoConstraints = false
        backBtn.addTarget(self, action: #selector(goBack), for: .touchUpInside)
        view.addSubview(backBtn)

        NSLayoutConstraint.activate([
            title.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            title.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 30),

            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 20),

            backBtn.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            backBtn.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -30),
            backBtn.widthAnchor.constraint(equalToConstant: 140),
            backBtn.heightAnchor.constraint(equalToConstant: 48)
        ])
    }

    @objc private func levelTapped(_ sender: UIButton) {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        let levelIndex = sender.tag
        let gameVC = GameViewController(level: levelIndex)
        gameVC.modalPresentationStyle = .fullScreen
        gameVC.modalTransitionStyle = .crossDissolve
        present(gameVC, animated: true)
    }

    @objc private func goBack() {
        dismiss(animated: true)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        backgroundGradient.frame = view.bounds
    }
}

// MARK: - LevelCard

final class LevelCard: UIButton {
    init(level: Int, name: String, enemyCount: String, color: UIColor) {
        super.init(frame: .zero)
        layer.cornerRadius = 16
        layer.borderWidth = 2
        layer.borderColor = color.cgColor
        layer.shadowColor = color.cgColor
        layer.shadowRadius = 10
        layer.shadowOpacity = 0.5
        layer.shadowOffset = .zero

        let bg = UIView()
        bg.backgroundColor = color.withAlphaComponent(0.1)
        bg.isUserInteractionEnabled = false
        bg.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bg)
        NSLayoutConstraint.activate([
            bg.topAnchor.constraint(equalTo: topAnchor),
            bg.bottomAnchor.constraint(equalTo: bottomAnchor),
            bg.leadingAnchor.constraint(equalTo: leadingAnchor),
            bg.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])

        let numLabel = UILabel()
        numLabel.text = "0\(level)"
        numLabel.font = UIFont(name: "AvenirNext-Heavy", size: 64) ??
                        UIFont.systemFont(ofSize: 64, weight: .black)
        numLabel.textColor = color.withAlphaComponent(0.3)
        numLabel.isUserInteractionEnabled = false
        numLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(numLabel)

        let nameLabel = UILabel()
        nameLabel.text = name
        nameLabel.numberOfLines = 2
        nameLabel.font = UIFont(name: "AvenirNext-Heavy", size: 22) ??
                         UIFont.systemFont(ofSize: 22, weight: .black)
        nameLabel.textColor = .white
        nameLabel.isUserInteractionEnabled = false
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(nameLabel)

        let diffLabel = UILabel()
        diffLabel.text = enemyCount
        diffLabel.font = UIFont(name: "AvenirNext-Medium", size: 13) ??
                         UIFont.systemFont(ofSize: 13, weight: .medium)
        diffLabel.textColor = color
        diffLabel.isUserInteractionEnabled = false
        diffLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(diffLabel)

        NSLayoutConstraint.activate([
            numLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            numLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),

            nameLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -44),
            nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            nameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),

            diffLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 8),
            diffLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16)
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.1) {
                self.transform = self.isHighlighted ?
                    CGAffineTransform(scaleX: 0.95, y: 0.95) : .identity
            }
        }
    }
}

// MARK: - TacticalGridView

final class TacticalGridView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.setStrokeColor(UIColor(red: 1, green: 0.5, blue: 0, alpha: 0.06).cgColor)
        ctx.setLineWidth(0.5)
        let spacing: CGFloat = 40
        var x: CGFloat = 0
        while x < rect.width {
            ctx.move(to: CGPoint(x: x, y: 0))
            ctx.addLine(to: CGPoint(x: x, y: rect.height))
            x += spacing
        }
        var y: CGFloat = 0
        while y < rect.height {
            ctx.move(to: CGPoint(x: 0, y: y))
            ctx.addLine(to: CGPoint(x: rect.width, y: y))
            y += spacing
        }
        ctx.strokePath()
    }
}

// MARK: - UILabel extension

extension UILabel {
    func letterSpacing(_ spacing: CGFloat) {
        guard let text = text else { return }
        let attrs = NSAttributedString(string: text,
                                       attributes: [.kern: spacing,
                                                    .font: font as Any,
                                                    .foregroundColor: textColor as Any])
        attributedText = attrs
    }
}
