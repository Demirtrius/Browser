import UIKit

protocol TabOverviewDelegate: AnyObject {
    func tabOverviewDidSelectTab(id: UUID)
    func tabOverviewDidCloseTab(id: UUID)
    func tabOverviewDidAddTab()
    func tabOverviewDidDismiss()
}

class TabOverviewView: UIView, UIGestureRecognizerDelegate {
    
    weak var delegate: TabOverviewDelegate?
    
    private var tabItems: [(id: UUID, title: String, url: String, snapshot: UIImage?)] = []
    private var activeTabId: UUID?
    private var cards: [UIView] = []
    
    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        sv.alwaysBounceVertical = true
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()
    
    private let plusButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("+", for: .normal)
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 30, weight: .regular)
        btn.backgroundColor = UIColor(hex: 0x3A3A3C)
        btn.layer.cornerRadius = 28
        btn.layer.shadowColor = UIColor.black.cgColor
        btn.layer.shadowOpacity = 0.5
        btn.layer.shadowOffset = CGSize(width: 0, height: 2)
        btn.layer.shadowRadius = 6
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()
    
    private let tabCountButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitleColor(.white, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 15, weight: .bold)
        btn.layer.borderWidth = 2
        btn.layer.borderColor = UIColor.white.cgColor
        btn.layer.cornerRadius = 5
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()
    
    // Layout constants
    private let hMargin: CGFloat = 8
    private let headerHeight: CGFloat = 46
    private let cardHeight: CGFloat = 380
    private let offsetStep: CGFloat = 118
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(hex: 0x121212)
        
        addSubview(tabCountButton)
        addSubview(scrollView)
        addSubview(plusButton)
        
        NSLayoutConstraint.activate([
            tabCountButton.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 10),
            tabCountButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            tabCountButton.widthAnchor.constraint(equalToConstant: 34),
            tabCountButton.heightAnchor.constraint(equalToConstant: 30),
            
            scrollView.topAnchor.constraint(equalTo: tabCountButton.bottomAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            plusButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            plusButton.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -20),
            plusButton.widthAnchor.constraint(equalToConstant: 56),
            plusButton.heightAnchor.constraint(equalToConstant: 56),
        ])
        
        plusButton.addTarget(self, action: #selector(newTabTapped), for: .touchUpInside)
        tabCountButton.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if !tabItems.isEmpty && cards.isEmpty {
            rebuildCards()
        }
    }
    
    func updateTabs(_ items: [(id: UUID, title: String, url: String, snapshot: UIImage?)], activeId: UUID?) {
        tabItems = items
        activeTabId = activeId
        rebuildCards()
    }
    
    private func rebuildCards() {
        cards.forEach { c in c.removeFromSuperview() }
        cards.removeAll()
        
        let w = scrollView.bounds.width
        guard w > 0 else { return }
        let cardW = w - hMargin * 2
        
        tabCountButton.setTitle("\(tabItems.count)", for: .normal)
        
        for (index, _) in tabItems.enumerated() {
            let card = makeCard(index: index, cardW: cardW)
            let y = CGFloat(index) * offsetStep
            card.frame = CGRect(x: hMargin, y: y, width: cardW, height: cardHeight)
            scrollView.addSubview(card)
            cards.append(card)
        }
        
        let contentH = CGFloat(max(0, tabItems.count - 1)) * offsetStep + cardHeight + 24
        scrollView.contentSize = CGSize(width: w, height: contentH)
        
        if let activeIdx = tabItems.firstIndex(where: { t in t.id == activeTabId }) {
            let targetY = CGFloat(activeIdx) * offsetStep
            let maxY = max(0, contentH - scrollView.bounds.height)
            scrollView.setContentOffset(CGPoint(x: 0, y: min(targetY, maxY)), animated: false)
        }
    }
    
    private func makeCard(index: Int, cardW: CGFloat) -> UIView {
        let item = tabItems[index]
        let isActive = item.id == activeTabId
        
        let card = UIView()
        card.backgroundColor = UIColor(hex: 0x2C2C2E)
        card.layer.cornerRadius = 10
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.4
        card.layer.shadowOffset = CGSize(width: 0, height: -1)
        card.layer.shadowRadius = 4
        card.tag = index
        
        let inner = UIView()
        inner.backgroundColor = UIColor(hex: 0x2C2C2E)
        inner.layer.cornerRadius = 10
        inner.clipsToBounds = true
        inner.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(inner)
        
        if isActive {
            card.layer.borderWidth = 2
            card.layer.borderColor = UIColor(hex: 0x6CB4FF).cgColor
        }
        
        // Header
        let header = UIView()
        header.backgroundColor = UIColor(hex: 0x3A3A3C)
        header.translatesAutoresizingMaskIntoConstraints = false
        inner.addSubview(header)
        
        let icon = UIImageView(image: UIImage(systemName: item.url.isEmpty ? "doc" : "globe"))
        icon.tintColor = UIColor(hex: 0xAEAEB2)
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(icon)
        
        let titleLabel = UILabel()
        titleLabel.text = item.title.isEmpty ? "New tab" : item.title
        titleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        titleLabel.textColor = .white
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(titleLabel)
        
        let closeBtn = UIButton(type: .system)
        closeBtn.setTitle("\u{00D7}", for: .normal)
        closeBtn.setTitleColor(UIColor(hex: 0xAEAEB2), for: .normal)
        closeBtn.titleLabel?.font = .systemFont(ofSize: 22, weight: .regular)
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        closeBtn.addTarget(self, action: #selector(closeTapped(_:)), for: .touchUpInside)
        closeBtn.accessibilityIdentifier = item.id.uuidString
        header.addSubview(closeBtn)
        
        // Preview area (thumbnail)
        let preview = UIView()
        preview.backgroundColor = UIColor(hex: 0xFFFFFF)
        preview.clipsToBounds = true
        preview.translatesAutoresizingMaskIntoConstraints = false
        inner.addSubview(preview)
        
        let thumb = UIImageView()
        thumb.contentMode = .scaleAspectFill
        thumb.clipsToBounds = true
        thumb.translatesAutoresizingMaskIntoConstraints = false
        preview.addSubview(thumb)
        
        let urlLabel = UILabel()
        urlLabel.font = .systemFont(ofSize: 12)
        urlLabel.textColor = UIColor(hex: 0x8E8E93)
        urlLabel.lineBreakMode = .byTruncatingTail
        urlLabel.translatesAutoresizingMaskIntoConstraints = false
        preview.addSubview(urlLabel)
        
        if let snap = item.snapshot {
            thumb.image = snap
            thumb.isHidden = false
            urlLabel.isHidden = true
            // Top-align the page snapshot so the top of the page is shown (like Chrome)
            let aspect = snap.size.height / max(1, snap.size.width)
            thumb.contentMode = .scaleToFill
            thumb.heightAnchor.constraint(equalTo: thumb.widthAnchor, multiplier: aspect).isActive = true
        } else {
            thumb.isHidden = true
            urlLabel.isHidden = false
            preview.backgroundColor = UIColor(hex: 0x1E1E1E)
            urlLabel.text = item.url.isEmpty ? "New Tab" : item.url
        }
        
        NSLayoutConstraint.activate([
            inner.topAnchor.constraint(equalTo: card.topAnchor),
            inner.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            inner.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            inner.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            
            header.topAnchor.constraint(equalTo: inner.topAnchor),
            header.leadingAnchor.constraint(equalTo: inner.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: inner.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: headerHeight),
            
            icon.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 14),
            icon.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 18),
            icon.heightAnchor.constraint(equalToConstant: 18),
            
            titleLabel.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: closeBtn.leadingAnchor, constant: -8),
            
            closeBtn.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -6),
            closeBtn.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            closeBtn.widthAnchor.constraint(equalToConstant: 40),
            closeBtn.heightAnchor.constraint(equalToConstant: 40),
            
            preview.topAnchor.constraint(equalTo: header.bottomAnchor),
            preview.leadingAnchor.constraint(equalTo: inner.leadingAnchor),
            preview.trailingAnchor.constraint(equalTo: inner.trailingAnchor),
            preview.bottomAnchor.constraint(equalTo: inner.bottomAnchor),
            
            thumb.topAnchor.constraint(equalTo: preview.topAnchor),
            thumb.leadingAnchor.constraint(equalTo: preview.leadingAnchor),
            thumb.trailingAnchor.constraint(equalTo: preview.trailingAnchor),
            
            urlLabel.topAnchor.constraint(equalTo: preview.topAnchor, constant: 12),
            urlLabel.leadingAnchor.constraint(equalTo: preview.leadingAnchor, constant: 14),
            urlLabel.trailingAnchor.constraint(equalTo: preview.trailingAnchor, constant: -14),
        ])
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(cardTapped(_:)))
        card.addGestureRecognizer(tap)
        
        let pan = UIPanGestureRecognizer(target: self, action: #selector(cardPanned(_:)))
        pan.delegate = self
        card.addGestureRecognizer(pan)
        
        return card
    }
    
    // MARK: - Gesture coexistence
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if let pan = gestureRecognizer as? UIPanGestureRecognizer, let card = pan.view {
            let v = pan.velocity(in: card)
            return abs(v.x) > abs(v.y) // only begin on horizontal swipe
        }
        return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    
    // MARK: - Interactions
    @objc private func cardTapped(_ g: UITapGestureRecognizer) {
        guard let card = g.view else { return }
        let index = card.tag
        guard index < tabItems.count else { return }
        delegate?.tabOverviewDidSelectTab(id: tabItems[index].id)
    }
    
    @objc private func cardPanned(_ g: UIPanGestureRecognizer) {
        guard let card = g.view else { return }
        let translation = g.translation(in: card)
        let tx = max(0, translation.x) // rightward only
        let progress = tx / card.bounds.width
        
        switch g.state {
        case .changed:
            card.transform = CGAffineTransform(translationX: tx, y: 0)
            card.alpha = max(0, 1 - progress * 1.2)
        case .ended, .cancelled:
            let velocity = g.velocity(in: card).x
            if progress > 0.22 || velocity > 700 { // higher sensitivity
                let idx = card.tag
                UIView.animate(withDuration: 0.2, animations: {
                    card.transform = CGAffineTransform(translationX: card.bounds.width * 1.5, y: 0)
                    card.alpha = 0
                }) { _ in
                    guard idx < self.tabItems.count else { return }
                    self.delegate?.tabOverviewDidCloseTab(id: self.tabItems[idx].id)
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
    
    @objc private func closeTapped(_ sender: UIButton) {
        guard let idStr = sender.accessibilityIdentifier,
              let uuid = UUID(uuidString: idStr) else { return }
        delegate?.tabOverviewDidCloseTab(id: uuid)
    }
    
    @objc private func newTabTapped() { delegate?.tabOverviewDidAddTab() }
    @objc private func dismissTapped() { delegate?.tabOverviewDidDismiss() }
}
