import UIKit

protocol SettingsViewDelegate: AnyObject {
    func settingsViewDidDismiss(_ settingsView: SettingsView)
}

class SettingsView: UIView {
    
    weak var delegate: SettingsViewDelegate?
    
    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()
    
    private let contentView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .vertical
        sv.spacing = 0
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()
    
    private let closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Done", for: .normal)
        button.setTitleColor(UIColor(hex: 0x6CB4FF), for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Settings"
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textColor = UIColor(hex: 0xFFFFFF)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: - Ad Blocker
    private let adBlockLabel = SettingsView.makeLabel(text: "Ad Blocker")
    private let adBlockSwitch: UISwitch = {
        let sw = UISwitch()
        sw.isOn = true
        sw.translatesAutoresizingMaskIntoConstraints = false
        return sw
    }()
    
    // MARK: - DNS over HTTPS
    private let dohLabel = SettingsView.makeLabel(text: "DNS over HTTPS")
    private let dohSwitch: UISwitch = {
        let sw = UISwitch()
        sw.isOn = true
        sw.translatesAutoresizingMaskIntoConstraints = false
        return sw
    }()
    
    private let dohProviderLabel = SettingsView.makeLabel(text: "DoH Provider")
    private let dohProviderControl: UISegmentedControl = {
        let sc = UISegmentedControl(items: ["Cloudflare", "Google"])
        sc.selectedSegmentIndex = 0
        sc.translatesAutoresizingMaskIntoConstraints = false
        return sc
    }()
    
    // MARK: - Download Folder
    private let downloadFolderLabel = SettingsView.makeLabel(text: "Download Folder")
    private let downloadFolderField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Downloads"
        tf.font = .systemFont(ofSize: 14)
        tf.textColor = UIColor(hex: 0xFFFFFF)
        tf.backgroundColor = UIColor(hex: 0x3A3A3C)
        tf.borderStyle = .none
        tf.layer.cornerRadius = 8
        tf.keyboardAppearance = .dark
        tf.autocapitalizationType = .none
        tf.autocorrectionType = .no
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()
    
    // MARK: - Clear Data
    private let clearButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Clear All Browsing Data", for: .normal)
        button.setTitleColor(.red, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // MARK: - About
    private let aboutLabel: UILabel = {
        let label = UILabel()
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        label.text = "Browser v\(version)"
        label.font = .systemFont(ofSize: 12)
        label.textColor = UIColor(hex: 0x999999)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    var onClearData: (() -> Void)?
    var onSettingsChanged: (() -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        loadSettings()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = UIColor(hex: 0x1C1C1E) // Dark settings bg
        
        addSubview(closeButton)
        addSubview(titleLabel)
        addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        // Build content
        addSection(header: "Privacy", views: [
            makeRow(label: adBlockLabel, control: adBlockSwitch),
            makeRow(label: dohLabel, control: dohSwitch),
            makeRow(label: dohProviderLabel, control: dohProviderControl)
        ])
        
        addSection(header: "Downloads", views: [
            makeRow(label: downloadFolderLabel, control: downloadFolderField)
        ])
        
        addSection(header: "", views: [clearButton])
        
        contentView.addArrangedSubview(aboutLabel)
        
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            
            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32)
        ])
        
        // Actions
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        clearButton.addTarget(self, action: #selector(clearTapped), for: .touchUpInside)
        
        adBlockSwitch.addTarget(self, action: #selector(settingsChanged), for: .valueChanged)
        dohSwitch.addTarget(self, action: #selector(settingsChanged), for: .valueChanged)
        dohProviderControl.addTarget(self, action: #selector(settingsChanged), for: .valueChanged)
    }
    
    private func loadSettings() {
        let settings = BrowserSettings.shared
        
        adBlockSwitch.isOn = settings.adBlockEnabled
        dohSwitch.isOn = settings.dohEnabled
        dohProviderControl.selectedSegmentIndex = BrowserSettings.DoHProvider.allCases.firstIndex(of: settings.dohProvider) ?? 0
        downloadFolderField.text = settings.downloadFolder
        dohProviderControl.isEnabled = settings.dohEnabled
    }
    
    func saveSettings() {
        let settings = BrowserSettings.shared
        
        settings.adBlockEnabled = adBlockSwitch.isOn
        settings.dohEnabled = dohSwitch.isOn
        
        let dohProviders = BrowserSettings.DoHProvider.allCases
        if dohProviderControl.selectedSegmentIndex < dohProviders.count {
            settings.dohProvider = dohProviders[dohProviderControl.selectedSegmentIndex]
        }
        
        settings.downloadFolder = downloadFolderField.text ?? "Downloads"
        
        onSettingsChanged?()
    }
    
    // MARK: - Helper Methods
    
    private static func makeLabel(text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = UIColor(hex: 0xE5E5E5)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }
    
    private func makeRow(label: UILabel, control: UIView) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false
        
        row.addSubview(label)
        row.addSubview(control)
        
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 44),
            
            label.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            label.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            
            control.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            control.centerYAnchor.constraint(equalTo: row.centerYAnchor)
        ])
        
        if let field = control as? UITextField {
            NSLayoutConstraint.activate([
                control.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 16),
                control.widthAnchor.constraint(greaterThanOrEqualToConstant: 120)
            ])
        } else {
            NSLayoutConstraint.activate([
                control.leadingAnchor.constraint(greaterThanOrEqualTo: label.trailingAnchor, constant: 16)
            ])
        }
        
        return row
    }
    
    private func addSection(header: String, views: [UIView]) {
        if !header.isEmpty {
            let headerLabel = UILabel()
            headerLabel.text = header
            headerLabel.font = .systemFont(ofSize: 12, weight: .bold)
            headerLabel.textColor = UIColor(hex: 0x6CB4FF)
            headerLabel.translatesAutoresizingMaskIntoConstraints = false
            contentView.addArrangedSubview(headerLabel)
            
            NSLayoutConstraint.activate([
                headerLabel.heightAnchor.constraint(equalToConstant: 24)
            ])
        }
        
        for view in views {
            contentView.addArrangedSubview(view)
            
            // Add separator
            let separator = UIView()
            separator.backgroundColor = UIColor(hex: 0x3A3A3C)
            separator.translatesAutoresizingMaskIntoConstraints = false
            contentView.addArrangedSubview(separator)
            
            NSLayoutConstraint.activate([
                separator.heightAnchor.constraint(equalToConstant: 0.5),
                separator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                separator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
            ])
        }
        
        // Section spacer
        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addArrangedSubview(spacer)
        NSLayoutConstraint.activate([
            spacer.heightAnchor.constraint(equalToConstant: 16)
        ])
    }
    
    // MARK: - Actions
    
    @objc private func closeTapped() {
        saveSettings()
        delegate?.settingsViewDidDismiss(self)
    }
    
    @objc private func clearTapped() {
        onClearData?()
    }
    
    @objc private func settingsChanged() {
        dohProviderControl.isEnabled = dohSwitch.isOn
        saveSettings()
    }
}
