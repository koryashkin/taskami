import UIKit

/// Full-document search palette: type to filter all items, arrow-key navigate, Return to jump.
/// Present it as a pageSheet — the sheet background is transparent so the blur shows through.
final class CommandPaletteViewController: UIViewController {

    var items: [TaskItem] = []
    var onSelect: ((TaskItem) -> Void)?

    private var filtered: [TaskItem] = []
    private var selectedIndex: Int = -1

    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
    private let searchField = UISearchTextField()
    private let separatorLine = UIView()
    private let tableView = UITableView(frame: .zero, style: .plain)

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        setupBlur()
        setupSearchField()
        setupSeparator()
        setupTableView()
        reloadData(query: "")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        searchField.becomeFirstResponder()
    }

    // MARK: - Layout

    private func setupBlur() {
        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.layer.cornerRadius = 12
        blurView.layer.masksToBounds = true
        view.addSubview(blurView)
        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: view.topAnchor),
            blurView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func setupSearchField() {
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholder = "Jump to task or project…"
        searchField.returnKeyType = .go
        searchField.addTarget(self, action: #selector(searchChanged), for: .editingChanged)
        searchField.delegate = self
        blurView.contentView.addSubview(searchField)
        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: blurView.contentView.topAnchor, constant: 12),
            searchField.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor, constant: 16),
            searchField.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor, constant: -16),
            searchField.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    private func setupSeparator() {
        separatorLine.translatesAutoresizingMaskIntoConstraints = false
        separatorLine.backgroundColor = .separator
        blurView.contentView.addSubview(separatorLine)
        NSLayoutConstraint.activate([
            separatorLine.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 8),
            separatorLine.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor),
            separatorLine.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor),
            separatorLine.heightAnchor.constraint(equalToConstant: 0.5),
        ])
    }

    private func setupTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.keyboardDismissMode = .none
        tableView.register(PaletteCell.self, forCellReuseIdentifier: PaletteCell.reuseID)
        blurView.contentView.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: separatorLine.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: blurView.contentView.bottomAnchor),
        ])
    }

    // MARK: - Filtering

    private func reloadData(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            filtered = items
        } else {
            let lower = trimmed.lowercased()
            filtered = items.filter { $0.content.lowercased().contains(lower) }
        }
        selectedIndex = filtered.isEmpty ? -1 : 0
        tableView.reloadData()
        if !filtered.isEmpty {
            tableView.selectRow(at: IndexPath(row: 0, section: 0), animated: false, scrollPosition: .none)
        }
    }

    @objc private func searchChanged() {
        reloadData(query: searchField.text ?? "")
    }

    // MARK: - Selection

    private func selectItem(at index: Int) {
        guard filtered.indices.contains(index) else { return }
        let item = filtered[index]
        dismiss(animated: true) { [weak self] in
            self?.onSelect?(item)
        }
    }
}

// MARK: - UITextFieldDelegate

extension CommandPaletteViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        selectItem(at: selectedIndex)
        return false
    }
}

// MARK: - Hardware keyboard navigation

extension CommandPaletteViewController {
    override var keyCommands: [UIKeyCommand]? {
        [
            UIKeyCommand(
                title: "Previous Result",
                action: #selector(moveUp),
                input: UIKeyCommand.inputUpArrow,
                modifierFlags: []
            ),
            UIKeyCommand(
                title: "Next Result",
                action: #selector(moveDown),
                input: UIKeyCommand.inputDownArrow,
                modifierFlags: []
            ),
            UIKeyCommand(
                title: "Dismiss",
                action: #selector(dismissPalette),
                input: UIKeyCommand.inputEscape,
                modifierFlags: []
            ),
        ]
    }

    @objc private func moveUp() {
        guard !filtered.isEmpty else { return }
        selectedIndex = max(0, selectedIndex - 1)
        let ip = IndexPath(row: selectedIndex, section: 0)
        tableView.selectRow(at: ip, animated: false, scrollPosition: .middle)
    }

    @objc private func moveDown() {
        guard !filtered.isEmpty else { return }
        selectedIndex = min(filtered.count - 1, selectedIndex + 1)
        let ip = IndexPath(row: selectedIndex, section: 0)
        tableView.selectRow(at: ip, animated: false, scrollPosition: .middle)
    }

    @objc private func dismissPalette() {
        dismiss(animated: true)
    }
}

// MARK: - UITableViewDataSource / Delegate

extension CommandPaletteViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        filtered.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: PaletteCell.reuseID, for: indexPath) as! PaletteCell
        cell.configure(with: filtered[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedIndex = indexPath.row
        selectItem(at: selectedIndex)
    }
}

// MARK: - Cell

private final class PaletteCell: UITableViewCell {
    static let reuseID = "PaletteCell"

    private let typeIcon = UILabel()
    private let contentLabel = UILabel()
    private let contextLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        let sel = UIView()
        sel.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.15)
        selectedBackgroundView = sel
        setupLayout()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupLayout() {
        typeIcon.translatesAutoresizingMaskIntoConstraints = false
        typeIcon.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        typeIcon.textColor = .secondaryLabel
        typeIcon.textAlignment = .center
        typeIcon.setContentHuggingPriority(.required, for: .horizontal)
        typeIcon.setContentCompressionResistancePriority(.required, for: .horizontal)

        contentLabel.translatesAutoresizingMaskIntoConstraints = false
        contentLabel.font = .systemFont(ofSize: 15, weight: .regular)
        contentLabel.numberOfLines = 1

        contextLabel.translatesAutoresizingMaskIntoConstraints = false
        contextLabel.font = .systemFont(ofSize: 12)
        contextLabel.textColor = .secondaryLabel
        contextLabel.numberOfLines = 1

        let textStack = UIStackView(arrangedSubviews: [contentLabel, contextLabel])
        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.axis = .vertical
        textStack.spacing = 1

        contentView.addSubview(typeIcon)
        contentView.addSubview(textStack)
        NSLayoutConstraint.activate([
            typeIcon.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            typeIcon.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            typeIcon.widthAnchor.constraint(equalToConstant: 18),

            textStack.leadingAnchor.constraint(equalTo: typeIcon.trailingAnchor, constant: 8),
            textStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            textStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            textStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
        ])
    }

    func configure(with item: TaskItem) {
        switch item.type {
        case .project: typeIcon.text = "◆"
        case .task:    typeIcon.text = item.isDone ? "✓" : "–"
        case .note:    typeIcon.text = "·"
        }

        let clean: String
        if let tagRange = TagParser.trailingTagsRange(in: item.content) {
            clean = String(item.content[item.content.startIndex..<tagRange.lowerBound])
                .trimmingCharacters(in: .whitespaces)
        } else {
            clean = item.content
        }
        contentLabel.text = clean.isEmpty ? item.content : clean

        let ancestors = item.ancestors.reversed().map(\.content)
        if ancestors.isEmpty {
            contextLabel.text = nil
            contextLabel.isHidden = true
        } else {
            contextLabel.text = ancestors.joined(separator: " › ")
            contextLabel.isHidden = false
        }
    }
}
