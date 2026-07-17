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
    
    private let stackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 12
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
        scrollView.addSubview(stackView)
        addSubview(newTabButton)
        
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 12),
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            
            scrollView.topAnchor.constraint(equalTo: closeButton.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            scrollView.bottomAnchor.constraint(equalTo: newTabButton.topAnchor, constant: -12),
            
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
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
        rebuildCards()
    }
    
    private func rebuildCards() {
        stackView.arrangedSubviews.forEach { v in v.removeFromSuperview() }
        
        for item in tabItems {
            let card = makeCard(id: item.id, title: item.title, url: item.url, isActive: item.id == activeTabId)
            stackView.addArrangedSubview(card)
        }
    }
    
    private func makeCard(id: UUID, title: String, url: String, isActive: Bool) -> UIView {
        let card = UIView()
        card.backgroundColor = isActive ? UIColor(hex: 0x2C2C2E) : UIColor(hex: 0x242426)
        card.layer.cornerRadius = 12
        if isActive { card.layer.borderWidth = 2; card.layer.borderColor = UIColor(hex: 0x6CB4FF).cgColor }
        card.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = title.isEmpty ? "New Tab" : title
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let urlLabel = UILabel()
        urlLabel.text = url.isEmpty ? "" : url
        urlLabel.font = .systemFont(ofSize: 12)
        urlLabel.textColor = UIColor(hex: 0x98989D)
        urlLabel.lineBreakMode = .byTruncatingTail
        urlLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let closeBtn = UIButton(type: .system)
        closeBtn.setTitle("X", for: .normal)
        closeBtn.setTitleColor(UIColor(hex: 0x98989D), for: .normal)
        closeBtn.titleLabel?.font = .systemFont(ofSize: 14, weight: .bold)
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        closeBtn.tag = Int(id.hashValue)
        closeBtn.addTarget(self, action: #selector(closeTapped(_:)), for: .touchUpInside)
        
        card.addSubview(titleLabel)
        card.addSubview(urlLabel)
        card.addSubview(closeBtn)
        
        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(greaterThanOrEqualToConstant: 60),
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: closeBtn.leadingAnchor, constant: -8),
            urlLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            urlLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            urlLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            urlLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
            closeBtn.topAnchor.constraint(equalTo: card.topAnchor, constant: 8),
            closeBtn.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -8),
            closeBtn.widthAnchor.constraint(equalToConstant: 24),
            closeBtn.heightAnchor.constraint(equalToConstant: 24),
        ])
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(cardTapped(_:)))
        card.addGestureRecognizer(tap)
        
        return card
    }
    
    @objc private func cardTapped(_ g: UITapGestureRecognizer) {
        guard let card = g.view else { return }
        let index = stackView.arrangedSubviews.firstIndex(of: card) ?? 0
        guard index < tabItems.count else { return }
        delegate?.tabOverviewDidSelectTab(id: tabItems[index].id)
    }
    
    @objc private func closeTapped(_ sender: UIButton) {
        let hashValue = sender.tag
        if let tab = tabItems.first(where: { t in t.id.hashValue == hashValue }) {
            delegate?.tabOverviewDidCloseTab(id: tab.id)
        }
    }
    
    @objc private func newTabTapped() { delegate?.tabOverviewDidAddTab() }
    @objc private func dismissTapped() { delegate?.tabOverviewDidDismiss() }
}
