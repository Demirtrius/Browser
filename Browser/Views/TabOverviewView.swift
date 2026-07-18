import UIKit

protocol TabOverviewDelegate: AnyObject {
    func tabOverviewDidSelectTab(id: UUID)
    func tabOverviewDidCloseTab(id: UUID)
    func tabOverviewDidAddTab()
    func tabOverviewDidDismiss()
}

class TabOverviewView: UIView {
    
    weak var delegate: TabOverviewDelegate?
    
    private var tabItems: [(id: UUID, title: String, url: String)] = []
    private var activeTabId: UUID?
    
    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()
    
    private let gridContainer: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 10
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()
    
    private let newTabButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("+ New Tab", for: .normal)
        btn.setTitleColor(UIColor(hex: 0x6CB4FF), for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()
    
    private let closeButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("Done", for: .normal)
        btn.setTitleColor(UIColor(hex: 0x6CB4FF), for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(hex: 0x1C1C1E)
        
        addSubview(closeButton)
        addSubview(scrollView)
        scrollView.addSubview(gridContainer)
        addSubview(newTabButton)
        
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 12),
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            
            scrollView.topAnchor.constraint(equalTo: closeButton.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            scrollView.bottomAnchor.constraint(equalTo: newTabButton.topAnchor, constant: -12),
            
            gridContainer.topAnchor.constraint(equalTo: scrollView.topAnchor),
            gridContainer.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            gridContainer.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            gridContainer.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            gridContainer.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            newTabButton.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -12),
            newTabButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            newTabButton.heightAnchor.constraint(equalToConstant: 44),
            newTabButton.widthAnchor.constraint(equalToConstant: 200),
        ])
        
        closeButton.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)
        newTabButton.addTarget(self, action: #selector(newTabTapped), for: .touchUpInside)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    func updateTabs(_ items: [(id: UUID, title: String, url: String)], activeId: UUID?) {
        tabItems = items
        activeTabId = activeId
        rebuildGrid()
    }
    
    private func rebuildGrid() {
        gridContainer.arrangedSubviews.forEach { v in v.removeFromSuperview() }
        
        var index = 0
        while index < tabItems.count {
            let row = makeRow(startIndex: index)
            gridContainer.addArrangedSubview(row)
            index += 2
        }
    }
    
    private func makeRow(startIndex: Int) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false
        
        let leftCard = makeCard(index: startIndex)
        row.addSubview(leftCard)
        
        if startIndex + 1 < tabItems.count {
            let rightCard = makeCard(index: startIndex + 1)
            row.addSubview(rightCard)
            
            NSLayoutConstraint.activate([
                leftCard.topAnchor.constraint(equalTo: row.topAnchor),
                leftCard.leadingAnchor.constraint(equalTo: row.leadingAnchor),
                leftCard.bottomAnchor.constraint(equalTo: row.bottomAnchor),
                leftCard.trailingAnchor.constraint(equalTo: row.centerXAnchor, constant: -5),
                
                rightCard.topAnchor.constraint(equalTo: row.topAnchor),
                rightCard.leadingAnchor.constraint(equalTo: row.centerXAnchor, constant: 5),
                rightCard.bottomAnchor.constraint(equalTo: row.bottomAnchor),
                rightCard.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            ])
        } else {
            // Single card on last row — center it with same width as half
            NSLayoutConstraint.activate([
                leftCard.topAnchor.constraint(equalTo: row.topAnchor),
                leftCard.leadingAnchor.constraint(equalTo: row.leadingAnchor),
                leftCard.bottomAnchor.constraint(equalTo: row.bottomAnchor),
                leftCard.trailingAnchor.constraint(equalTo: row.centerXAnchor, constant: -5),
            ])
        }
        
        return row
    }
    
    private func makeCard(index: Int) -> UIView {
        let item = tabItems[index]
        let isActive = item.id == activeTabId
        
        let card = UIView()
        card.backgroundColor = isActive ? UIColor(hex: 0x2C2C2E) : UIColor(hex: 0x242426)
        card.layer.cornerRadius = 12
        if isActive {
            card.layer.borderWidth = 2
            card.layer.borderColor = UIColor(hex: 0x6CB4FF).cgColor
        }
        card.translatesAutoresizingMaskIntoConstraints = false
        card.tag = index
        
        // Tab index badge
        let badge = UILabel()
        badge.text = "\(index + 1)"
        badge.font = .systemFont(ofSize: 11, weight: .bold)
        badge.textColor = UIColor(hex: 0x98989D)
        badge.translatesAutoresizingMaskIntoConstraints = false
        
        // Close button
        let closeBtn = UIButton(type: .system)
        closeBtn.setTitle("\u{00D7}", for: .normal) // × symbol
        closeBtn.setTitleColor(UIColor(hex: 0x98989D), for: .normal)
        closeBtn.titleLabel?.font = .systemFont(ofSize: 18, weight: .bold)
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        closeBtn.addTarget(self, action: #selector(closeTapped(_:)), for: .touchUpInside)
        // Store tab id in accessibilityIdentifier
        closeBtn.accessibilityIdentifier = item.id.uuidString
        
        // Title
        let titleLabel = UILabel()
        titleLabel.text = item.title.isEmpty ? "New Tab" : item.title
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 2
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // URL
        let urlLabel = UILabel()
        urlLabel.text = item.url.isEmpty ? "" : item.url
        urlLabel.font = .systemFont(ofSize: 11)
        urlLabel.textColor = UIColor(hex: 0x98989D)
        urlLabel.lineBreakMode = .byTruncatingTail
        urlLabel.translatesAutoresizingMaskIntoConstraints = false
        
        card.addSubview(badge)
        card.addSubview(closeBtn)
        card.addSubview(titleLabel)
        card.addSubview(urlLabel)
        
        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(equalToConstant: 100),
            
            badge.topAnchor.constraint(equalTo: card.topAnchor, constant: 8),
            badge.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 10),
            
            closeBtn.topAnchor.constraint(equalTo: card.topAnchor, constant: 4),
            closeBtn.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -4),
            closeBtn.widthAnchor.constraint(equalToConstant: 28),
            closeBtn.heightAnchor.constraint(equalToConstant: 28),
            
            titleLabel.topAnchor.constraint(equalTo: badge.bottomAnchor, constant: 4),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -10),
            
            urlLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            urlLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 10),
            urlLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -10),
            urlLabel.bottomAnchor.constraint(lessThanOrEqualTo: card.bottomAnchor, constant: -8),
        ])
        
        // Tap to select
        let tap = UITapGestureRecognizer(target: self, action: #selector(cardTapped(_:)))
        card.addGestureRecognizer(tap)
        
        // Swipe to close
        let swipe = UIPanGestureRecognizer(target: self, action: #selector(cardSwiped(_:)))
        card.addGestureRecognizer(swipe)
        
        return card
    }
    
    // MARK: - Card Interactions
    
    @objc private func cardTapped(_ g: UITapGestureRecognizer) {
        guard let card = g.view else { return }
        let index = card.tag
        guard index < tabItems.count else { return }
        delegate?.tabOverviewDidSelectTab(id: tabItems[index].id)
    }
    
    @objc private func closeTapped(_ sender: UIButton) {
        guard let idStr = sender.accessibilityIdentifier,
              let uuid = UUID(uuidString: idStr) else { return }
        delegate?.tabOverviewDidCloseTab(id: uuid)
    }
    
    // MARK: - Swipe to Close
    
    @objc private func cardSwiped(_ g: UIPanGestureRecognizer) {
        guard let card = g.view else { return }
        let translation = g.translation(in: card)
        let progress = translation.x / card.bounds.width
        
        switch g.state {
        case .changed:
            card.transform = CGAffineTransform(translationX: translation.x, y: 0)
            card.alpha = max(0, 1 - abs(progress) * 1.5)
        case .ended, .cancelled:
            if abs(progress) > 0.3 {
                let direction: CGFloat = progress > 0 ? 1 : -1
                UIView.animate(withDuration: 0.2, animations: {
                    card.transform = CGAffineTransform(translationX: direction * card.bounds.width * 2, y: 0)
                    card.alpha = 0
                }) { _ in
                    let index = card.tag
                    guard index < self.tabItems.count else { return }
                    self.delegate?.tabOverviewDidCloseTab(id: self.tabItems[index].id)
                }
            } else {
                UIView.animate(withDuration: 0.2) {
                    card.transform = .identity
                    card.alpha = 1
                }
            }
        default:
            break
        }
    }
    
    @objc private func newTabTapped() { delegate?.tabOverviewDidAddTab() }
    @objc private func dismissTapped() { delegate?.tabOverviewDidDismiss() }
}
