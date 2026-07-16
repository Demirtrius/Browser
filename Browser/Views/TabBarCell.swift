import UIKit

class TabBarCell: UIView {
    
    private let faviconImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.tintColor = UIColor(hex: 0x5F6368)
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = UIColor(hex: 0x333333)
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("×", for: .normal)
        button.setTitleColor(UIColor(hex: 0x5F6368), for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        button.contentEdgeInsets = UIEdgeInsets(top: 2, left: 4, bottom: 2, right: 4)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    var onCloseTapped: (() -> Void)?
    var onTapped: (() -> Void)?
    
    var isActive: Bool = false {
        didSet {
            updateAppearance()
        }
    }
    
    var isLoading: Bool = false {
        didSet {
            if isLoading {
                activityIndicator.startAnimating()
                faviconImageView.isHidden = true
            } else {
                activityIndicator.stopAnimating()
                faviconImageView.isHidden = false
            }
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        layer.cornerRadius = 8
        clipsToBounds = true
        
        addSubview(faviconImageView)
        addSubview(titleLabel)
        addSubview(closeButton)
        addSubview(activityIndicator)
        
        NSLayoutConstraint.activate([
            faviconImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            faviconImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            faviconImageView.widthAnchor.constraint(equalToConstant: 16),
            faviconImageView.heightAnchor.constraint(equalToConstant: 16),
            
            titleLabel.leadingAnchor.constraint(equalTo: faviconImageView.trailingAnchor, constant: 6),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -4),
            
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            closeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            activityIndicator.centerXAnchor.constraint(equalTo: faviconImageView.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: faviconImageView.centerYAnchor),
            
            heightAnchor.constraint(equalToConstant: 32)
        ])
        
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tabTapped))
        addGestureRecognizer(tapGesture)
        
        updateAppearance()
    }
    
    private func updateAppearance() {
        backgroundColor = isActive ? UIColor(hex: 0xFFFFFF) : UIColor(hex: 0xC8C8C8)
        titleLabel.textColor = isActive ? UIColor(hex: 0x333333) : UIColor(hex: 0x666666)
    }
    
    func configure(title: String, favicon: UIImage?) {
        titleLabel.text = title
        faviconImageView.image = favicon ?? defaultFavicon()
    }
    
    private func defaultFavicon() -> UIImage {
        return UIImage(systemName: "globe") ?? UIImage()
    }
    
    @objc private func closeTapped() {
        onCloseTapped?()
    }
    
    @objc private func tabTapped() {
        onTapped?()
    }
}
