import UIKit

final class TaskItemCell: UICollectionViewCell {
    static let reuseIdentifier = "TaskItemCell"

    private let contentLabel = UITextView()
    private let dashLabel = UILabel()
    // Stored reference so configure() can update it directly — no constraint search loop
    private var indentLeadingConstraint: NSLayoutConstraint!
    private var dashWidthConstraint: NSLayoutConstraint!

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

        indentLeadingConstraint = dashLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16)
        dashWidthConstraint = dashLabel.widthAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            indentLeadingConstraint,
            dashLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),

            contentLabel.leadingAnchor.constraint(equalTo: dashLabel.trailingAnchor),
            contentLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            contentLabel.topAnchor.constraint(equalTo: contentView.topAnchor),
            contentLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }

    func configure(with item: TaskItem, highlighter: TaskPaperTextHighlighter) {
        let indentOffset = CGFloat(item.indentLevel) * highlighter.theme.indentWidth + 16

        // Update indent
        indentLeadingConstraint.constant = indentOffset

        // Show/hide dash for tasks — zero-width when hidden avoids layout gaps
        let isTask = item.type == .task
        dashLabel.isHidden = !isTask
        if isTask {
            dashLabel.text = "- "
            dashLabel.font = highlighter.theme.font
            dashLabel.textColor = item.isDone ? highlighter.theme.doneColor.uiColor : highlighter.theme.taskColor.uiColor
            dashWidthConstraint.isActive = false
        } else {
            dashWidthConstraint.isActive = true
        }

        contentLabel.attributedText = highlighter.highlight(item)
        contentView.backgroundColor = highlighter.theme.backgroundColor.uiColor
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        contentLabel.attributedText = nil
        dashWidthConstraint.isActive = false
        dashLabel.isHidden = false
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
