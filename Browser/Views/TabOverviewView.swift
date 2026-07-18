import UIKit

protocol TabOverviewDelegate: AnyObject {
    func tabOverviewDidSelectTab(id: UUID)
    func tabOverviewDidCloseTab(id: UUID)
    func tabOverviewDidAddTab()
    func tabOverviewDidDismiss()
}

class TabOverviewView: UIView, UIScrollViewDelegate {
    
    weak var delegate: TabOverviewDelegate?
    
    private var tabItems: [(id: UUID, title: String, url: String)] = []
    private var activeTabId: UUID?
    private var cardViews: [UIView] = []
    
    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsHorizontalScrollIndicator = false
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()
    
    private let plusButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("+", for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 28, weight: .bold)
        btn.backgroundColor = UIColor(hex: 0x3A3A3C)
        btn.layer.cornerRadius = 22
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()
    
    private let tabCountLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = .systemFont(ofSize: 13, weight: .medium)
        lbl.textColor = UIColor(hex: 0x98989D)
        lbl.textAlignment = .center
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(hex: 0x1C1C1E)
        
        addSubview(scrollView)
        addSubview(plusButton)
        addSubview(tabCountLabel)
        scrollView.delegate = self
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 50),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -60),
            
            plusButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            plusButton.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -16),
            plusButton.widthAnchor.constraint(equalToConstant: 44),
            plusButton.heightAnchor.constraint(equalToConstant: 44),
            
            tabCountLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            tabCountLabel.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -24),
        ])
        
        plusButton.addTarget(self, action: #selector(newTabTapped), for: .touchUpInside)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    func updateTabs(_ items: [(id: UUID, title: String, url: String)], activeId: UUID?) {
        tabItems = items
        activeTabId = activeId
        rebuildCards()
    }
    
    private func rebuildCards() {
        cardViews.forEach { item in item.removeFromSuperview() }
        cardViews.removeAll()
        
        let w = scrollView.bounds.width
        let h = scrollView.bounds.height
        guard w > 0, h > 0 else { return }
        
        let cardW = w * 0.7
        let cardH = h * 0.65
        let pageW = w
        
        scrollView.contentSize = CGSize(width: CGFloat(tabItems.count) * pageW, height: h)
        
        for (index, item) in tabItems.enumerated() {
            let isActive = item.id == activeTabId
            let card = makeCard(index: index, item: item, isActive: isActive, cardW: cardW, cardH: cardH)
            
            let pageX = CGFloat(index) * pageW
            card.frame = CGRect(x: pageX + (pageW - cardW) / 2, y: (h - cardH) / 2, width: cardW, height: cardH)
            scrollView.addSubview(card)
            cardViews.append(card)
        }
        
        if let activeIdx = tabItems.firstIndex(where: { t in t.id == activeTabId }) {
            scrollView.contentOffset = CGPoint(x: CGFloat(activeIdx) * pageW, y: 0)
        }
        
        tabCountLabel.text = "\(tabItems.count) tab\(tabItems.count == 1 ? "" : "s")"
        updateCardZOrder()
    }
    
    private func makeCard(index: Int, item: (id: UUID, title: String, url: String), isActive: Bool, cardW: CGFloat, cardH: CGFloat) -> UIView {
        let card = UIView()
        card.backgroundColor = isActive ? UIColor(hex: 0x2C2C2E) : UIColor(hex: 0x242426)
        card.layer.cornerRadius = 12
        if isActive {
            card.layer.borderWidth = 2
            card.layer.borderColor = UIColor(hex: 0x6CB4FF).cgColor
        }
        card.tag = index
        card.clipsToBounds = true
        
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
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(cardTapped(_:)))
        card.addGestureRecognizer(tap)
        
        let swipe = UIPanGestureRecognizer(target: self, action: #selector(cardSwiped(_:)))
        card.addGestureRecognizer(swipe)
        
        return card
    }
    
    private func updateCardZOrder() {
        let pageW = scrollView.bounds.width
        guard pageW > 0 else { return }
        let centerX = scrollView.contentOffset.x + pageW / 2
        
        for (i, card) in cardViews.enumerated() {
            let cardCenterX = card.frame.midX
            let distance = abs(cardCenterX - centerX)
            card.layer.zPosition = -distance
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateCardZOrder()
        
        let pageW = scrollView.bounds.width
        guard pageW > 0 else { return }
        let progress = scrollView.contentOffset.x / pageW
        let nearestIndex = Int(progress.rounded())
        
        for (i, card) in cardViews.enumerated() {
            let distance = abs(progress - CGFloat(i))
            let scale = max(0.85, 1.0 - distance * 0.1)
            let alpha = max(0.3, 1.0 - distance * 0.4)
            card.transform = CGAffineTransform(scaleX: scale, y: scale)
            card.alpha = alpha
        }
        
        if nearestIndex >= 0 && nearestIndex < tabItems.count {
            activeTabId = tabItems[nearestIndex].id
        }
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let pageW = scrollView.bounds.width
        guard pageW > 0 else { return }
        let index = Int((scrollView.contentOffset.x / pageW).rounded())
        guard index >= 0 && index < tabItems.count else { return }
        activeTabId = tabItems[index].id
        delegate?.tabOverviewDidSelectTab(id: tabItems[index].id)
    }
    
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
    
    @objc private func cardSwiped(_ g: UIPanGestureRecognizer) {
        guard let card = g.view else { return }
        let translation = g.translation(in: card)
        let progress = translation.x / card.bounds.width
        
        switch g.state {
        case .changed:
            card.transform = CGAffineTransform(translationX: translation.x, y: translation.y * 0.3)
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
}
