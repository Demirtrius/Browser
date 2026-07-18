import UIKit

protocol DownloadsPanelDelegate: AnyObject {
    func downloadsPanelDidCancel(id: UUID)
    func downloadsPanelDidDismiss()
}

class DownloadsPanelView: UIView {
    
    weak var delegate: DownloadsPanelDelegate?
    private var downloads: [DownloadItem] = []
    
    private let backgroundView = UIView()
    private let containerView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(hex: 0x1C1C1E)
        v.layer.cornerRadius = 16
        v.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    
    private let handleView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(hex: 0x48484A)
        v.layer.cornerRadius = 2.5
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    
    private let titleLabel: UILabel = {
        let lbl = UILabel()
        lbl.text = "Downloads"
        lbl.font = .systemFont(ofSize: 18, weight: .bold)
        lbl.textColor = .white
        lbl.textAlignment = .center
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()
    
    private let tableView: UITableView = {
        let tv = UITableView()
        tv.backgroundColor = .clear
        tv.separatorStyle = .none
        tv.translatesAutoresizingMaskIntoConstraints = false
        tv.register(DownloadCell.self, forCellReuseIdentifier: "dl")
        return tv
    }()
    
    private let emptyLabel: UILabel = {
        let lbl = UILabel()
        lbl.text = "No active downloads"
        lbl.font = .systemFont(ofSize: 15)
        lbl.textColor = UIColor(hex: 0x98989D)
        lbl.textAlignment = .center
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.black.withAlphaComponent(0.5)
        
        addSubview(backgroundView)
        backgroundView.addSubview(containerView)
        containerView.addSubview(handleView)
        containerView.addSubview(titleLabel)
        containerView.addSubview(tableView)
        containerView.addSubview(emptyLabel)
        
        tableView.delegate = self
        tableView.dataSource = self
        
        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            containerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            containerView.heightAnchor.constraint(lessThanOrEqualToConstant: 500),
            
            handleView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 10),
            handleView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            handleView.widthAnchor.constraint(equalToConstant: 36),
            handleView.heightAnchor.constraint(equalToConstant: 5),
            
            titleLabel.topAnchor.constraint(equalTo: handleView.bottomAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            tableView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            tableView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            
            emptyLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
        ])
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(backgroundTapped))
        backgroundView.addGestureRecognizer(tap)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    func updateDownloads(_ items: [DownloadItem]) {
        downloads = items
        tableView.reloadData()
        emptyLabel.isHidden = !items.isEmpty
    }
    
    @objc private func backgroundTapped() {
        delegate?.downloadsPanelDidDismiss()
    }
}

// MARK: - TableView
extension DownloadsPanelView: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return downloads.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "dl", for: indexPath) as! DownloadCell
        let item = downloads[indexPath.row]
        cell.configure(with: item)
        cell.onCancel = { [weak self] in
            self?.delegate?.downloadsPanelDidCancel(id: item.id)
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 64
    }
}

// MARK: - Cell
class DownloadCell: UITableViewCell {
    private let iconView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.tintColor = UIColor(hex: 0x6CB4FF)
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let nameLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = .systemFont(ofSize: 14, weight: .medium)
        lbl.textColor = .white
        lbl.lineBreakMode = .byTruncatingTail
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()
    
    private let progressLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = .systemFont(ofSize: 12)
        lbl.textColor = UIColor(hex: 0x98989D)
        lbl.translatesAutoresizingMaskIntoConstraints = false
        return lbl
    }()
    
    private let progressBar: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(hex: 0x3A3A3C)
        v.layer.cornerRadius = 2
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    
    private let progressFill: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(hex: 0x6CB4FF)
        v.layer.cornerRadius = 2
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    
    private let cancelBtn: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle("\u{00D7}", for: .normal)
        btn.setTitleColor(UIColor(hex: 0x98989D), for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 20, weight: .regular)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()
    
    var onCancel: (() -> Void)?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        
        contentView.addSubview(iconView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(progressLabel)
        contentView.addSubview(progressBar)
        progressBar.addSubview(progressFill)
        contentView.addSubview(cancelBtn)
        
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 28),
            iconView.heightAnchor.constraint(equalToConstant: 28),
            
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            nameLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(equalTo: cancelBtn.leadingAnchor, constant: -8),
            
            progressLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            progressLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            progressLabel.trailingAnchor.constraint(equalTo: cancelBtn.leadingAnchor, constant: -8),
            
            progressBar.topAnchor.constraint(equalTo: progressLabel.bottomAnchor, constant: 4),
            progressBar.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            progressBar.trailingAnchor.constraint(equalTo: cancelBtn.leadingAnchor, constant: -8),
            progressBar.heightAnchor.constraint(equalToConstant: 4),
            
            progressFill.topAnchor.constraint(equalTo: progressBar.topAnchor),
            progressFill.leadingAnchor.constraint(equalTo: progressBar.leadingAnchor),
            progressFill.bottomAnchor.constraint(equalTo: progressBar.bottomAnchor),
            progressFill.widthAnchor.constraint(equalTo: progressBar.widthAnchor, multiplier: 0),
            
            cancelBtn.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            cancelBtn.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            cancelBtn.widthAnchor.constraint(equalToConstant: 32),
            cancelBtn.heightAnchor.constraint(equalToConstant: 32),
        ])
        
        cancelBtn.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    func configure(with item: DownloadItem) {
        iconView.image = UIImage(systemName: DownloadManager.iconFor(filename: item.filename))
        nameLabel.text = item.filename
        progressLabel.text = item.progressText
        
        let pct = item.progress
        progressFill.widthAnchor.constraint(equalTo: progressBar.widthAnchor, multiplier: CGFloat(pct)).isActive = true
        layoutIfNeeded()
    }
    
    @objc private func cancelTapped() {
        onCancel?()
    }
}
