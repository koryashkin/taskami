import UIKit

/// Thin bar displayed at the top of the editor when the user has focused into a subtree.
/// Shows the path to the focused item and a button to step back out.
final class FocusBreadcrumbView: UIView {

    var onFocusOut: (() -> Void)?

    private let backButton = UIButton(type: .system)
    private let pathLabel = UILabel()
    private let separator = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        backgroundColor = .secondarySystemBackground

        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "chevron.left",
                               withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold))
        config.title = "Focus Out"
        config.imagePadding = 4
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 8)
        backButton.configuration = config
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        backButton.setContentHuggingPriority(.required, for: .horizontal)
        backButton.setContentCompressionResistancePriority(.required, for: .horizontal)

        pathLabel.font = .systemFont(ofSize: 13, weight: .regular)
        pathLabel.textColor = .secondaryLabel
        pathLabel.lineBreakMode = .byTruncatingHead
        pathLabel.translatesAutoresizingMaskIntoConstraints = false

        separator.backgroundColor = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false

        addSubview(backButton)
        addSubview(pathLabel)
        addSubview(separator)

        NSLayoutConstraint.activate([
            backButton.leadingAnchor.constraint(equalTo: leadingAnchor),
            backButton.topAnchor.constraint(equalTo: topAnchor),
            backButton.bottomAnchor.constraint(equalTo: separator.topAnchor),

            pathLabel.leadingAnchor.constraint(equalTo: backButton.trailingAnchor),
            pathLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            pathLabel.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),

            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5),

            heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    /// Update the displayed path. `parts` is the ancestry chain from root to focused item.
    func setPath(_ parts: [String]) {
        pathLabel.text = parts.joined(separator: " › ")
    }

    @objc private func backTapped() {
        onFocusOut?()
    }
}
