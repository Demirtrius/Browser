import UIKit

protocol TabBarViewDelegate: AnyObject {
    func tabBarView(_ tabBarView: TabBarView, didSelectTabAt index: Int)
    func tabBarView(_ tabBarView: TabBarView, didCloseTabAt index: Int)
    func tabBarViewDidTapNewTab(_ tabBarView: TabBarView)
}

class TabBarView: UIView {
    
    weak var delegate: TabBarViewDelegate?
    
    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsHorizontalScrollIndicator = false
        sv.showsVerticalScrollIndicator = false
        sv.alwaysBounceHorizontal = true
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()
    
    private let stackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.spacing = 4
        sv.alignment = .center
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()
    
    private let newTabButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "plus"), for: .normal)
        button.tintColor = UIColor(hex: 0x5F6368)
        button.contentEdgeInsets = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private var tabCells: [TabBarCell] = []
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = UIColor(hex: 0xDEDEDE)
        
        addSubview(scrollView)
        scrollView.addSubview(stackView)
        addSubview(newTabButton)
        
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            scrollView.trailingAnchor.constraint(equalTo: newTabButton.leadingAnchor, constant: -4),
            scrollView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
            
            newTabButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            newTabButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            newTabButton.widthAnchor.constraint(equalToConstant: 32),
            newTabButton.heightAnchor.constraint(equalToConstant: 32),
            
            heightAnchor.constraint(equalToConstant: 40)
        ])
        
        newTabButton.addTarget(self, action: #selector(newTabTapped), for: .touchUpInside)
    }
    
    func updateTabs(tabs: [Tab], activeIndex: Int) {
        // Remove old cells
        tabCells.forEach { $0.removeFromSuperview() }
        tabCells.removeAll()
        
        // Create new cells
        for (index, tab) in tabs.enumerated() {
            let cell = TabBarCell()
            cell.configure(title: tab.title, favicon: tab.favicon)
            cell.isActive = (index == activeIndex)
            cell.isLoading = tab.isLoading
            
            cell.onTapped = { [weak self] in
                self?.delegate?.tabBarView(self!, didSelectTabAt: index)
            }
            
            cell.onCloseTapped = { [weak self] in
                self?.delegate?.tabBarView(self!, didCloseTabAt: index)
            }
            
            cell.widthAnchor.constraint(greaterThanOrEqualToConstant: 100).isActive = true
            cell.widthAnchor.constraint(lessThanOrEqualToConstant: 180).isActive = true
            
            stackView.addArrangedSubview(cell)
            tabCells.append(cell)
        }
    }
    
    @objc private func newTabTapped() {
        delegate?.tabBarViewDidTapNewTab(self)
    }
}
