import UIKit

protocol EditorKeyboardAccessoryDelegate: AnyObject {
    func accessoryDidTapIndent()
    func accessoryDidTapOutdent()
    func accessoryDidTapToggleDone()
    func accessoryDidTapCursorLeft()
    func accessoryDidTapCursorRight()
    func accessoryDidTapDismiss()
}

final class EditorKeyboardAccessoryView: UIInputView {

    weak var delegate: EditorKeyboardAccessoryDelegate?

    private let stackView = UIStackView()

    override init(frame: CGRect, inputViewStyle: UIInputView.Style) {
        super.init(frame: frame, inputViewStyle: inputViewStyle)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    convenience init() {
        self.init(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44), inputViewStyle: .keyboard)
        allowsSelfSizing = true
    }

    private func setupViews() {
        backgroundColor = .systemGroupedBackground

        stackView.axis = .horizontal
        stackView.distribution = .equalSpacing
        stackView.alignment = .center
        stackView.spacing = 4
        stackView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
        ])

        // Indent (Tab)
        addButton(systemName: "increase.indent", id: "accessory-indent", action: #selector(indentTapped))

        // Outdent (Shift-Tab)
        addButton(systemName: "decrease.indent", id: "accessory-outdent", action: #selector(outdentTapped))

        addSeparator()

        // Toggle @done
        addButton(systemName: "checkmark.circle", id: "accessory-done", action: #selector(doneTapped))

        addSeparator()

        // Cursor left
        addButton(systemName: "chevron.left", id: "accessory-cursor-left", action: #selector(cursorLeftTapped))

        // Cursor right
        addButton(systemName: "chevron.right", id: "accessory-cursor-right", action: #selector(cursorRightTapped))

        addSeparator()

        // Dismiss keyboard
        addButton(systemName: "keyboard.chevron.compact.down", id: "accessory-dismiss", action: #selector(dismissTapped))
    }

    @discardableResult
    private func addButton(systemName: String, id: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        button.setImage(UIImage(systemName: systemName, withConfiguration: config), for: .normal)
        button.tintColor = .label
        button.accessibilityIdentifier = id
        button.addTarget(self, action: action, for: .touchUpInside)
        button.widthAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        button.heightAnchor.constraint(equalToConstant: 36).isActive = true
        stackView.addArrangedSubview(button)
        return button
    }

    private func addSeparator() {
        let separator = UIView()
        separator.backgroundColor = .separator
        separator.widthAnchor.constraint(equalToConstant: 1).isActive = true
        separator.heightAnchor.constraint(equalToConstant: 24).isActive = true
        stackView.addArrangedSubview(separator)
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 44)
    }

    // MARK: - Actions

    @objc private func indentTapped() { delegate?.accessoryDidTapIndent() }
    @objc private func outdentTapped() { delegate?.accessoryDidTapOutdent() }
    @objc private func doneTapped() { delegate?.accessoryDidTapToggleDone() }
    @objc private func cursorLeftTapped() { delegate?.accessoryDidTapCursorLeft() }
    @objc private func cursorRightTapped() { delegate?.accessoryDidTapCursorRight() }
    @objc private func dismissTapped() { delegate?.accessoryDidTapDismiss() }
}
