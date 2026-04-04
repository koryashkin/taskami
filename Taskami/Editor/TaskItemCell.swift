import UIKit

final class TaskItemCell: UICollectionViewCell {
    static let reuseIdentifier = "TaskItemCell"

    private let contentLabel = UITextView()
    private let dashLabel = UILabel()
    private var currentItem: TaskItem?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        contentLabel.isEditable = false
        contentLabel.isSelectable = false
        contentLabel.isScrollEnabled = false
        contentLabel.textContainerInset = UIEdgeInsets(top: 4, left: 0, bottom: 4, right: 8)
        contentLabel.textContainer.lineFragmentPadding = 0
        contentLabel.backgroundColor = .clear
        contentLabel.translatesAutoresizingMaskIntoConstraints = false

        dashLabel.text = "- "
        dashLabel.translatesAutoresizingMaskIntoConstraints = false
        dashLabel.setContentHuggingPriority(.required, for: .horizontal)
        dashLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        contentView.addSubview(dashLabel)
        contentView.addSubview(contentLabel)

        NSLayoutConstraint.activate([
            dashLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            dashLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),

            contentLabel.leadingAnchor.constraint(equalTo: dashLabel.trailingAnchor),
            contentLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            contentLabel.topAnchor.constraint(equalTo: contentView.topAnchor),
            contentLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }

    func configure(with item: TaskItem, highlighter: TaskPaperTextHighlighter) {
        currentItem = item

        let indentOffset = CGFloat(item.indentLevel) * highlighter.theme.indentWidth + 16

        // Show/hide dash for tasks
        dashLabel.isHidden = item.type != .task
        dashLabel.font = highlighter.theme.font
        dashLabel.textColor = item.isDone ? highlighter.theme.doneColor : highlighter.theme.taskColor

        // Update leading constraint for indent
        for constraint in contentView.constraints {
            if constraint.firstAnchor == dashLabel.leadingAnchor {
                constraint.constant = indentOffset
            }
        }

        // Apply highlighted attributed text
        contentLabel.attributedText = highlighter.highlight(item)

        // Background
        contentView.backgroundColor = highlighter.theme.backgroundColor
    }

    override func preferredLayoutAttributesFitting(
        _ layoutAttributes: UICollectionViewLayoutAttributes
    ) -> UICollectionViewLayoutAttributes {
        let attributes = super.preferredLayoutAttributesFitting(layoutAttributes)
        let targetSize = CGSize(width: layoutAttributes.frame.width, height: UIView.layoutFittingCompressedSize.height)
        let size = contentView.systemLayoutSizeFitting(
            targetSize,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        attributes.frame.size.height = max(size.height, 32)
        return attributes
    }
}
