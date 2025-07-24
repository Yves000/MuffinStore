import UIKit

class AppTableViewCell: UITableViewCell {
    static let identifier = "AppTableViewCell"
    
    private let appIconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.layer.cornerRadius = 13.33
        imageView.layer.cornerCurve = .continuous
        imageView.layer.borderWidth = 0.33
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private let appNameLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let appVersionLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
        
        // IMPORTANT: Must set selectionStyle to .default for native selection circles to work
        selectionStyle = .default
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        let labelStackView = UIStackView(arrangedSubviews: [appNameLabel, appVersionLabel])
        labelStackView.axis = .vertical
        labelStackView.spacing = 2
        labelStackView.alignment = .leading
        labelStackView.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(appIconImageView)
        contentView.addSubview(labelStackView)
        
        // Separator line position - aligned with text labels
        separatorInset = UIEdgeInsets(top: 0, left: 92, bottom: 0, right: 0) // 16 + 60 + 16 = 92
        
        // Set initial border color
        updateBorderColor()
        
        NSLayoutConstraint.activate([
            appIconImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            appIconImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            appIconImageView.widthAnchor.constraint(equalToConstant: 60),
            appIconImageView.heightAnchor.constraint(equalToConstant: 60),
            
            labelStackView.leadingAnchor.constraint(equalTo: appIconImageView.trailingAnchor, constant: 16),
            labelStackView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            labelStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 76)
        ])
    }
    
    func configure(with app: AppModel, isBlocked: Bool = false) {
        appNameLabel.text = app.name
        appVersionLabel.text = "Version \(app.version)"
        appIconImageView.image = app.icon ?? UIImage(systemName: "app.dashed")
        
        // Change version label color based on status
        if isBlocked {
            appVersionLabel.textColor = .systemOrange  // Orange = blocked
        } else {
            appVersionLabel.textColor = .secondaryLabel  // Gray = normal
        }
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        // Let iOS handle the native selection circles in editing mode
        // Don't override accessoryType - iOS will show circles automatically
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateBorderColor()
        }
    }
    
    private func updateBorderColor() {
        if traitCollection.userInterfaceStyle == .dark {
            // Dark mode: sehr subtiles helles grau
            appIconImageView.layer.borderColor = UIColor(white: 1.0, alpha: 0.15).cgColor
        } else {
            // Light mode: sehr subtiles dunkles grau
            appIconImageView.layer.borderColor = UIColor(white: 0.0, alpha: 0.15).cgColor
        }
    }
}