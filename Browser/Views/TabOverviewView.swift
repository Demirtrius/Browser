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
    private var activeIndex: Int = 0
    
    private let container = UIView()
    private var cardLayers: [(view: UIView, index: Int)] = []
    
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
        
        addSubview(container)
        container.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 40),
            container.leadingAnchor.constraint(equalTo: leadingAnchor),
            container.trailingAnchor.constraint(equalTo: trailingAnchor),
            container.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -60),
        ])
        
        addSubview(plusButton)
        addSubview(tabCountLabel)
        
        NSLayoutConstraint.activate([
            plusButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            plusButton.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -16),
            plusButton.widthAnchor.constraint(equalToConstant: 44),
            plusButton.heightAnchor.constraint(equalToConstant: 44),
            tabCountLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            tabCountLabel.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -24),
        ])
        
        plusButton.addTarget(self, action: #selector(newTabTapped), for: .touchUpInside)
        
        let swipeLeft = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeLeft.direction = .left
        container.addGestureRecognizer(swipeLeft)
        
        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeRight.direction = .right
        container.addGestureRecognizer(swipeRight)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(containerTapped(_:)))
        container.addGestureRecognizer(tap)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    func updateTabs(_ items: [(id: UUID, title: String, url: String)], activeId: UUID?) {
        tabItems = items
        activeTabId = activeId
        if let idx = tabItems.firstIndex(where: { t in t.id == activeId }) {
            activeIndex = idx
        }
        rebuildStack()
    }
    
    private func rebuildStack() {
        cardLayers.forEach { item in item.view.removeFromSuperview() }
        cardLayers.removeAll()
        
        guard !tabItems.isEmpty else { return }
        
        let w = container.bounds.width
        let h = container.bounds.height
        guard w > 0, h > 0 else { return }
        
        let cardW = w * 0.75
        let cardH = h * 0.7
        let centerX = (w - cardW) / 2
        let centerY = (h - cardH) / 2
        
        tabCountLabel.text = "\(tabItems.count) tab\(tabItems.count == 1 ? "" : "s")"
        
        let maxVisible = min(tabItems.count, 5)
        let startIdx = max(0, activeIndex - 2)
        let endIdx = min(tabItems.count, startIdx + maxVisible)
        
        for i in startIdx..<endIdx {
            let offset = i - activeIndex
            let card = makeCard(index: i, cardW: cardW, cardH: cardH)
            
            let scale = 1.0 - CGFloat(abs(offset)) * 0.06
            let xOffset = CGFloat(offset) * 20
            let alpha = 1.0 - CGFloat(abs(offset)) * 0.2
            
            card.frame = CGRect(x: centerX + xOffset, y: centerY + CGFloat(offset) * 8, width: cardW, height: cardH)
            card.transform = CGAffineTransform(scaleX: scale, y: scale)
            card.alpha = alpha
            card.layer.zPosition = CGFloat(100 - abs(offset))
            
            container.addSubview(card)
            cardLayers.append((view: card, index: i))
        }
    }
    
    private func makeCard(index: Int, cardW: CGFloat, cardH: CGFloat) -> UIView {
        let item = tabItems[index]
        let isActive = item.id == activeTabId
        
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
        
        return card
    }
    
    @objc private func handleSwipe(_ g: UISwipeGestureRecognizer) {
        guard !tabItems.isEmpty else { return }
        
        if g.direction == .left, activeIndex < tabItems.count - 1 {
            animateCardSwitch(to: activeIndex + 1)
        } else if g.direction == .right, activeIndex > 0 {
            animateCardSwitch(to: activeIndex - 1)
        }
    }
    
    private func animateCardSwitch(to newIndex: Int) {
        activeIndex = newIndex
        activeTabId = tabItems[newIndex].id
        
        UIView.animate(withDuration: 0.25, animations: {
            self.cardLayers.forEach { item in
                item.view.alpha = 0
            }
        }) { _ in
            self.rebuildStack()
            self.delegate?.tabOverviewDidSelectTab(id: self.tabItems[newIndex].id)
        }
    }
    
    @objc private func containerTapped(_ g: UITapGestureRecognizer) {
        let location = g.location(in: container)
        for layer in cardLayers.reversed() {
            if layer.view.frame.contains(location) {
                if layer.index == activeIndex {
                    delegate?.tabOverviewDidSelectTab(id: tabItems[layer.index].id)
                } else {
                    animateCardSwitch(to: layer.index)
                }
                return
            }
        }
    }
    
    @objc private func closeTapped(_ sender: UIButton) {
        guard let idStr = sender.accessibilityIdentifier,
              let uuid = UUID(uuidString: idStr) else { return }
        delegate?.tabOverviewDidCloseTab(id: uuid)
    }
    
    @objc private func newTabTapped() { delegate?.tabOverviewDidAddTab() }
}
