import UIKit

/// Full-screen overlay showing a split-panel reference book.
/// Left panel: alphabetical list of all 172 GameAlbum labels.
/// Right panel: selected drawing image + label title.
final class AlbumBookViewController: UIViewController {

    // MARK: - Data

    /// All 172 asset labels sorted alphabetically.
    static let allLabels: [String] = [
        "airplane", "alarm clock", "angel", "ant", "apple", "axe",
        "backpack", "banana", "bed", "bee", "bell", "bicycle", "binoculars", "book",
        "bowl", "brain", "bread", "butterfly",
        "cabinet", "cactus", "cake", "calculator", "camel", "camera", "candle",
        "cannon", "carrot", "castle", "cat", "chair", "chandelier", "closet",
        "cloud", "comb", "computer monitor", "computer-mouse", "cone-ice-cream",
        "cow", "crab", "crocodile", "crown",
        "diamond", "dog", "dolphin", "donut", "door", "dragon",
        "ear", "elephant", "envelope", "eye", "eyeglasses",
        "face", "fan", "feather", "fire hydrant", "fish", "flashlight",
        "flower with stem", "flying bird", "foot", "fork", "frog", "frying-pan",
        "gift", "giraffe", "grapes", "guitar",
        "hamburger", "hammer", "hand", "hat", "head-phones", "hedgehog",
        "helicopter", "helmet", "horse", "hot-dog", "hourglass", "house",
        "human-skeleton",
        "kangaroo", "kayak", "key", "keyboard-computer", "knife",
        "ladder", "laptop", "leaf", "lightbulb", "lion", "lobster",
        "microphone", "microscope", "monkey", "moon", "mouse (animal)", "mouth", "mug", "mushroom",
        "nose",
        "octopus", "owl",
        "palm tree", "pant", "paper clip", "parachute", "pear", "pen",
        "penguin", "person sitting", "person walking", "pig", "pineapple", "pizza",
        "potted plant", "power outlet", "pretzel", "pumpkin",
        "rabbit", "radio", "rainbow", "rocket", "rollerblades", "rooster",
        "satellite", "scissors", "scorpion", "screwdriver", "sea turtle", "sedan",
        "shark", "sheep", "ship", "shoe", "skateboard", "skull", "skyscraper",
        "snail", "snake", "socks", "spider", "spoon", "squirrel", "stapler",
        "strawberry", "streetlight", "submarine", "suitcase", "sun", "swan", "syringe",
        "t-shirt", "table", "teapot", "teddy-bear", "tennis-racket", "tent",
        "tiger", "tomato", "tooth", "toothbrush", "traffic light", "train", "tree",
        "ufo", "umbrella",
        "wheel", "windmill", "wineglass", "wrist-watch",
        "zebra"
    ]

    struct RoomSection {
        let name: String
        let items: [String]
    }

    private let sections: [RoomSection] = [
        RoomSection(name: "Laboratorium", items: [
            "angel", "ant", "bee", "brain", "butterfly", "cactus", "camel", "cat", "cow", "crab", "crocodile", "crown", "dog", "dolphin", "dragon", "ear", "elephant", "eye", "eyeglasses", "face", "feather", "fish", "flower with stem", "flying bird", "foot", "frog", "giraffe", "hand", "hat", "hedgehog", "helmet", "horse", "human-skeleton", "kangaroo", "leaf", "lion", "lobster", "monkey", "mouse (animal)", "mouth", "nose", "octopus", "owl", "palm tree", "pant", "penguin", "person sitting", "person walking", "pig", "potted plant", "rabbit", "rooster", "scorpion", "sea turtle", "shark", "sheep", "shoe", "skull", "snail", "snake", "socks", "spider", "squirrel", "swan", "t-shirt", "tiger", "tooth", "tree", "wrist-watch", "zebra"
        ]),
        RoomSection(name: "Engine Room", items: [
            "airplane", "alarm clock", "bicycle", "camera", "cannon", "castle", "cloud", "computer monitor", "diamond", "envelope", "fire hydrant", "gift", "head-phones", "helicopter", "house", "kayak", "keyboard-computer", "laptop", "microphone", "parachute", "radio", "rainbow", "rocket", "rollerblades", "satellite", "sedan", "ship", "skateboard", "skyscraper", "streetlight", "submarine", "teddy-bear", "tent", "traffic light", "train", "windmill"
        ]),
        RoomSection(name: "Storage", items: [
            "axe", "backpack", "bed", "bell", "binoculars", "book", "bowl", "cabinet", "calculator", "candle", "chair", "chandelier", "closet", "comb", "computer-mouse", "door", "fan", "flashlight", "fork", "frying-pan", "guitar", "hammer", "hourglass", "key", "knife", "ladder", "lightbulb", "microscope", "mug", "paper clip", "pen", "power outlet", "scissors", "screwdriver", "spoon", "stapler", "syringe", "table", "teapot", "tennis-racket", "toothbrush", "umbrella", "wheel", "wineglass"
        ]),
        RoomSection(name: "Kitchen", items: [
            "apple", "banana", "bread", "cake", "carrot", "cone-ice-cream", "donut", "grapes", "hamburger", "hot-dog", "mushroom", "pear", "pineapple", "pizza", "pretzel", "pumpkin", "strawberry", "tomato"
        ]),
        RoomSection(name: "Cockpit", items: [
            "moon", "sun", "ufo"
        ])
    ]

    private var selectedIndex = 0
    private var expandedSections: Set<Int> = [0] // Laboratorium expanded by default
    private var selectedIndexPath: IndexPath? = IndexPath(row: 0, section: 0)

    // MARK: - UI Components

    private let backgroundView: UIVisualEffectView = {
        let blur = UIBlurEffect(style: .systemUltraThinMaterialDark)
        let view = UIVisualEffectView(effect: blur)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.08, green: 0.10, blue: 0.16, alpha: 0.92)
        view.layer.cornerRadius = 20
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.white.withAlphaComponent(0.12).cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let headerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.12, green: 0.15, blue: 0.22, alpha: 1)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "REFERENCE ALBUM"
        label.font = GameFont.custom(size: 20, weight: 700).uiFont
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var closeButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("✕", for: .normal)
        btn.titleLabel?.font = GameFont.custom(size: 18, weight: 600).uiFont
        btn.setTitleColor(.white, for: .normal)
        btn.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    private let headerDivider: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.white.withAlphaComponent(0.10)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.backgroundColor = .clear
        tv.separatorColor = UIColor.white.withAlphaComponent(0.08)
        tv.showsVerticalScrollIndicator = true
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    private let panelDivider: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.white.withAlphaComponent(0.10)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let imageContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.96, green: 0.96, blue: 0.95, alpha: 1)
        view.layer.cornerRadius = 12
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let imageTitleLabel: UILabel = {
        let label = UILabel()
        label.font = GameFont.custom(size: 22, weight: 700).uiFont
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let imageCountLabel: UILabel = {
        let label = UILabel()
        label.font = GameFont.custom(size: 13, weight: 400).uiFont
        label.textColor = UIColor.white.withAlphaComponent(0.45)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        let globalIndex = getGlobalIndex(for: IndexPath(row: 0, section: 0))
        updateRightPanel(index: globalIndex, animated: false)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let ip = selectedIndexPath {
            tableView.selectRow(at: ip, animated: false, scrollPosition: .top)
        }
    }

    private func getGlobalIndex(for indexPath: IndexPath) -> Int {
        let label = sections[indexPath.section].items[indexPath.row]
        return Self.allLabels.firstIndex(of: label) ?? 0
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = .clear

        view.addSubview(backgroundView)
        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        view.addSubview(containerView)
        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            containerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24)
        ])

        // Header
        containerView.addSubview(headerView)
        headerView.layer.cornerRadius = 20
        headerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: containerView.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 56)
        ])

        headerView.addSubview(titleLabel)
        headerView.addSubview(closeButton)
        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            closeButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44)
        ])

        containerView.addSubview(headerDivider)
        NSLayoutConstraint.activate([
            headerDivider.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            headerDivider.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            headerDivider.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            headerDivider.heightAnchor.constraint(equalToConstant: 1)
        ])

        // Left panel — table view (30% width)
        containerView.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: headerDivider.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            tableView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            tableView.widthAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: 0.30)
        ])

        // Vertical divider between panels
        containerView.addSubview(panelDivider)
        NSLayoutConstraint.activate([
            panelDivider.topAnchor.constraint(equalTo: headerDivider.bottomAnchor),
            panelDivider.leadingAnchor.constraint(equalTo: tableView.trailingAnchor),
            panelDivider.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            panelDivider.widthAnchor.constraint(equalToConstant: 1)
        ])

        // Right panel
        containerView.addSubview(imageTitleLabel)
        containerView.addSubview(imageContainerView)
        containerView.addSubview(imageCountLabel)
        imageContainerView.addSubview(imageView)

        NSLayoutConstraint.activate([
            // Image Container View (starts right below the header divider and stretches down)
            imageContainerView.topAnchor.constraint(equalTo: headerDivider.bottomAnchor, constant: 16),
            imageContainerView.leadingAnchor.constraint(equalTo: panelDivider.trailingAnchor, constant: 24),
            imageContainerView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            imageContainerView.bottomAnchor.constraint(equalTo: imageTitleLabel.topAnchor, constant: -12),

            // Coretan/Doodle Image (centered, exactly 224x224 to prevent stretching/pixelation)
            imageView.centerXAnchor.constraint(equalTo: imageContainerView.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: imageContainerView.centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 224),
            imageView.heightAnchor.constraint(equalToConstant: 224),

            // Animal Name Label (moved below the image)
            imageTitleLabel.leadingAnchor.constraint(equalTo: panelDivider.trailingAnchor, constant: 24),
            imageTitleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24),
            imageTitleLabel.bottomAnchor.constraint(equalTo: imageCountLabel.topAnchor, constant: -4),

            // Image Count Label (anchored to the bottom)
            imageCountLabel.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
            imageCountLabel.leadingAnchor.constraint(equalTo: panelDivider.trailingAnchor, constant: 24),
            imageCountLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -24)
        ])

        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(AlbumLabelCell.self, forCellReuseIdentifier: AlbumLabelCell.reuseID)
    }

    // MARK: - Right Panel Update

    private func updateRightPanel(index: Int, animated: Bool = true) {
        guard index < Self.allLabels.count else { return }
        selectedIndex = index
        let label = Self.allLabels[index]
        imageTitleLabel.text = label.titleCased()
        imageCountLabel.text = "\(index + 1) / \(Self.allLabels.count)"
        let newImage = UIImage(named: label)
        if animated {
            UIView.transition(with: imageView, duration: 0.22, options: .transitionCrossDissolve) {
                self.imageView.image = newImage
            }
        } else {
            imageView.image = newImage
        }
    }

    // MARK: - Actions

    @objc private func toggleSection(_ sender: UIButton) {
        AudioManager.shared.playButtonSound()
        let section = sender.tag
        if expandedSections.contains(section) {
            expandedSections.remove(section)
        } else {
            expandedSections.insert(section)
        }
        tableView.reloadSections(IndexSet(integer: section), with: .fade)
    }

    @objc private func closeTapped() {
        AudioManager.shared.playButtonSound()
        dismiss(animated: true)
    }
}

// MARK: - UITableViewDataSource & Delegate

extension AlbumBookViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        expandedSections.contains(section) ? sections[section].items.count : 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: AlbumLabelCell.reuseID, for: indexPath) as! AlbumLabelCell
        let name = sections[indexPath.section].items[indexPath.row].titleCased()
        let isSelected = selectedIndexPath == indexPath
        cell.configure(with: name, isSelected: isSelected)
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat { 44 }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerButton = UIButton(type: .custom)
        headerButton.backgroundColor = UIColor(red: 0.12, green: 0.15, blue: 0.22, alpha: 1.0)
        headerButton.tag = section
        headerButton.addTarget(self, action: #selector(toggleSection(_:)), for: .touchUpInside)

        let titleLabel = UILabel()
        titleLabel.text = sections[section].name.uppercased()
        titleLabel.font = GameFont.custom(size: 13, weight: 700).uiFont
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerButton.addSubview(titleLabel)

        let arrowLabel = UILabel()
        let isExpanded = expandedSections.contains(section)
        arrowLabel.text = isExpanded ? "▼" : "▶"
        arrowLabel.font = GameFont.custom(size: 11, weight: 700).uiFont
        arrowLabel.textColor = UIColor.white.withAlphaComponent(0.6)
        arrowLabel.translatesAutoresizingMaskIntoConstraints = false
        headerButton.addSubview(arrowLabel)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: headerButton.leadingAnchor, constant: 14),
            titleLabel.centerYAnchor.constraint(equalTo: headerButton.centerYAnchor),

            arrowLabel.trailingAnchor.constraint(equalTo: headerButton.trailingAnchor, constant: -14),
            arrowLabel.centerYAnchor.constraint(equalTo: headerButton.centerYAnchor)
        ])

        // Add a very subtle bottom separator for sections
        let sep = UIView()
        sep.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        sep.translatesAutoresizingMaskIntoConstraints = false
        headerButton.addSubview(sep)
        NSLayoutConstraint.activate([
            sep.leadingAnchor.constraint(equalTo: headerButton.leadingAnchor),
            sep.trailingAnchor.constraint(equalTo: headerButton.trailingAnchor),
            sep.bottomAnchor.constraint(equalTo: headerButton.bottomAnchor),
            sep.heightAnchor.constraint(equalToConstant: 1)
        ])

        return headerButton
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 48
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedIndexPath = indexPath
        let globalIndex = getGlobalIndex(for: indexPath)
        updateRightPanel(index: globalIndex)
        tableView.reloadData()
        tableView.selectRow(at: indexPath, animated: false, scrollPosition: .none)
    }
}

// MARK: - AlbumLabelCell

final class AlbumLabelCell: UITableViewCell {
    static let reuseID = "AlbumLabelCell"

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectedBackgroundView = {
            let v = UIView()
            v.backgroundColor = UIColor(red: 0.25, green: 0.45, blue: 0.80, alpha: 0.35)
            return v
        }()
        contentView.addSubview(nameLabel)
        NSLayoutConstraint.activate([
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            nameLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(with name: String, isSelected: Bool) {
        nameLabel.text = name
        nameLabel.font = GameFont.custom(size: 13, weight: isSelected ? 700 : 400).uiFont
        nameLabel.textColor = isSelected
            ? UIColor(red: 0.60, green: 0.82, blue: 1.0, alpha: 1)
            : UIColor.white.withAlphaComponent(0.75)
    }
}

// MARK: - String Helper

private extension String {
    /// Capitalizes each word in the string.
    func titleCased() -> String {
        split(separator: " ").map { word in
            let s = String(word)
            return s.prefix(1).uppercased() + s.dropFirst().lowercased()
        }.joined(separator: " ")
    }
}
