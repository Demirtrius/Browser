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
        sv.isPagingEnabled = true
        sv.showsHorizontalScrollIndicator = false
        sv.decelerationRate = .fast
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
    
    private let tabCounterLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = .systemFont(ofSize: 13, weight: .medium)
        lbl.textColor = UIColor(hex: 0x98989D)
        lbl.textAlignment = .center
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()
    
    private var cardWidth: CGFloat = 0
    private var cardHeight: CGFloat = 0
    private let cardSpacing: CGFloat = 16
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(hex: 0x1C1C1E)
        
        addSubview(closeButton)
        addSubview(scrollView)
        addSubview(newTabButton)
        
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 12),
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            
            scrollView.topAnchor.constraint(equalTo: closeButton.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: newTabButton.topAnchor, constant: -8),
            
            newTabButton.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -12),
            newTabButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            newTabButton.heightAnchor.constraint(equalToConstant: 44),
            newTabButton.widthAnchor.constraint(equalToConstant: 200),
        ])
        
        closeButton.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)
        newTabButton.addTarget(self, action: #selector(newTabTapped), for: .touchUpInside)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        let w = scrollView.bounds.width
        let h = scrollView.bounds.height
        guard w > 0, h > 0 else { return }
        
        cardWidth = w * 0.75
        cardHeight = h * 0.55
        
        // Re-layout existing cards
        for (i, card) in scrollView.subviews.enumerated() {
            let x = CGFloat(i) * w + (w - cardWidth) / 2
            let y = (h - cardHeight) / 2
            card.frame = CGRect(x: x, y: y, width: cardWidth, height: cardHeight)
        }
        
        scrollView.contentSize = CGSize(width: CGFloat(tabItems.count) * w, height: h)
        
        // Scroll to active tab
        if let activeIdx = tabItems.firstIndex(where: { t in t.id == activeTabId }) {
            scrollView.contentOffset = CGPoint(x: CGFloat(activeIdx) * w, y: 0)
        }
        
        // Update tab counter
        tabCounterLabel.text = "\(tabItems.count) tab\(tabItems.count == 1 ? "" : "s")"
    }
    
    func updateTabs(_ items: [(id: UUID, title: String, url: String)], activeId: UUID?) {
        tabItems = items
        activeTabId = activeId
        rebuildCards()
    }
    
    private func rebuildCards() {
        scrollView.subviews.forEach { item in item.removeFromSuperview() }
        
        let w = scrollView.bounds.width
        let h = scrollView.bounds.height
        guard w > 0, h > 0 else { return }
        
        cardWidth = w * 0.75
        cardHeight = h * 0.55
        
        for (index, item) in tabItems.enumerated() {
            let isActive = item.id == activeTabId
            let card = makeCard(index: index, item: item, isActive: isActive)
            
            let x = CGFloat(index) * w + (w - cardWidth) / 2
            let y = (h - cardHeight) / 2
            card.frame = CGRect(x: x, y: y, width: cardWidth, height: cardHeight)
            scrollView.addSubview(card)
        }
        
        scrollView.contentSize = CGSize(width: CGFloat(tabItems.count) * w, height: h)
        
        // Scroll to active tab
        if let activeIdx = tabItems.firstIndex(where: { t in t.id == activeTabId }) {
            scrollView.contentOffset = CGPoint(x: CGFloat(activeIdx) * w, y: 0)
        }
        
        tabCounterLabel.text = "\(tabItems.count) tab\(tabItems.count == 1 ? "" : "s")"
    }
    
    private func makeCard(index: Int, item: (id: UUID, title: String, url: String), isActive: Bool) -> UIView {
        let card = UIView()
        card.backgroundColor = isActive ? UIColor(hex: 0x2C2C2E) : UIColor(hex: 0x242426)
        card.layer.cornerRadius = 12
        if isActive {
            card.layer.borderWidth = 2
            card.layer.borderColor = UIColor(hex: 0x6CB4FF).cgColor
        }
        card.tag = index
        card.clipsToBounds = true
        
        // Top bar with index + close
        let topBar = UIView()
        topBar.backgroundColor = UIColor(hex: 0x1C1C1E)
        topBar.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(topBar)
        
        let badge = UILabel()
        badge.text = "\(index + 1)"
        badge.font = .systemFont(ofSize: 12, weight: .bold)
        badge.textColor = UIColor(hex: 0x98989D)
        badge.translatesAutoresizingMaskIntoConstraints = false
        topBar.addSubview(badge)
        
        let closeBtn = UIButton(type: .system)
        closeBtn.setTitle("\u{00D7}", for: .normal)
        closeBtn.setTitleColor(UIColor(hex: 0x98989D), for: .normal)
        closeBtn.titleLabel?.font = .systemFont(ofSize: 20, weight: .bold)
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        closeBtn.addTarget(self, action: #selector(closeTapped(_:)), for: .touchUpInside)
        closeBtn.accessibilityIdentifier = item.id.uuidString
        topBar.addSubview(closeBtn)
        
        // Preview area (title + url)
        let titleLabel = UILabel()
        titleLabel.text = item.title.isEmpty ? "New Tab" : item.title
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 2
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(titleLabel)
        
        let urlLabel = UILabel()
        urlLabel.text = item.url.isEmpty ? "" : item.url
        urlLabel.font = .systemFont(ofSize: 11)
        urlLabel.textColor = UIColor(hex: 0x98989D)
        urlLabel.lineBreakMode = .byTruncatingTail
        urlLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(urlLabel)
        
        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: card.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 36),
            
            badge.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 10),
            badge.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            
            closeBtn.trailingAnchor.constraint(equalTo: topBar.trailingAnchor, constant: -4),
            closeBtn.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            closeBtn.widthAnchor.constraint(equalToConstant: 32),
            closeBtn.heightAnchor.constraint(equalToConstant: 32),
            
            titleLabel.topAnchor.constraint(equalTo: topBar.bottomAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            
            urlLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            urlLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            urlLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
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
