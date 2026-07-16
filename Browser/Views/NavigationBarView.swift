import UIKit

protocol NavigationBarViewDelegate: AnyObject {
    func navigationBarDidTapBack(_ navBar: NavigationBarView)
    func navigationBarDidTapForward(_ navBar: NavigationBarView)
    func navigationBarDidTapReload(_ navBar: NavigationBarView)
    func navigationBarDidTapHome(_ navBar: NavigationBarView)
    func navigationBarDidTapSettings(_ navBar: NavigationBarView)
    func navigationBar(_ navBar: NavigationBarView, didSubmitText text: String)
    func navigationBarDidBeginEditing(_ navBar: NavigationBarView)
    func navigationBarDidEndEditing(_ navBar: NavigationBarView)
}

class NavigationBarView: UIView {
    
    weak var delegate: NavigationBarViewDelegate?
    
    private let backButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        button.tintColor = UIColor(hex: 0x5F6368)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let forwardButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "chevron.right"), for: .normal)
        button.tintColor = UIColor(hex: 0x5F6368)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let reloadButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "arrow.clockwise"), for: .normal)
        button.tintColor = UIColor(hex: 0x5F6368)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let homeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "house"), for: .normal)
        button.tintColor = UIColor(hex: 0x5F6368)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let omniboxContainer: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(hex: 0xF1F1F1)
        view.layer.cornerRadius = 16
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let lockIcon: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(systemName: "magnifyingglass")
        iv.tintColor = UIColor(hex: 0x5F6368)
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    let omnibox: UITextField = {
        let field = UITextField()
        field.font = .systemFont(ofSize: 14)
        field.textColor = UIColor(hex: 0x333333)
        field.clearButtonMode = .whileEditing
        field.returnKeyType = .go
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }()
    
    private let settingsButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "gearshape"), for: .normal)
        button.tintColor = UIColor(hex: 0x5F6368)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let progressView: UIProgressView = {
        let pv = UIProgressView(progressViewStyle: .bar)
        pv.progressTintColor = UIColor(hex: 0x4285F4)
        pv.trackTintColor = .clear
        pv.translatesAutoresizingMaskIntoConstraints = false
        pv.isHidden = true
        return pv
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .white
        
        addSubview(backButton)
        addSubview(forwardButton)
        addSubview(reloadButton)
        addSubview(homeButton)
        addSubview(omniboxContainer)
        addSubview(settingsButton)
        addSubview(progressView)
        
        omniboxContainer.addSubview(lockIcon)
        omniboxContainer.addSubview(omnibox)
        
        NSLayoutConstraint.activate([
            // Back button
            backButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            backButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 32),
            backButton.heightAnchor.constraint(equalToConstant: 32),
            
            // Forward button
            forwardButton.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: 2),
            forwardButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            forwardButton.widthAnchor.constraint(equalToConstant: 32),
            forwardButton.heightAnchor.constraint(equalToConstant: 32),
            
            // Reload button
            reloadButton.leadingAnchor.constraint(equalTo: forwardButton.trailingAnchor, constant: 2),
            reloadButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            reloadButton.widthAnchor.constraint(equalToConstant: 32),
            reloadButton.heightAnchor.constraint(equalToConstant: 32),
            
            // Home button
            homeButton.leadingAnchor.constraint(equalTo: reloadButton.trailingAnchor, constant: 4),
            homeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            homeButton.widthAnchor.constraint(equalToConstant: 32),
            homeButton.heightAnchor.constraint(equalToConstant: 32),
            
            // Omnibox container
            omniboxContainer.leadingAnchor.constraint(equalTo: homeButton.trailingAnchor, constant: 8),
            omniboxContainer.trailingAnchor.constraint(equalTo: settingsButton.leadingAnchor, constant: -8),
            omniboxContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
            omniboxContainer.heightAnchor.constraint(equalToConstant: 32),
            
            // Lock icon
            lockIcon.leadingAnchor.constraint(equalTo: omniboxContainer.leadingAnchor, constant: 10),
            lockIcon.centerYAnchor.constraint(equalTo: omniboxContainer.centerYAnchor),
            lockIcon.widthAnchor.constraint(equalToConstant: 16),
            lockIcon.heightAnchor.constraint(equalToConstant: 16),
            
            // Omnibox text field
            omnibox.leadingAnchor.constraint(equalTo: lockIcon.trailingAnchor, constant: 6),
            omnibox.trailingAnchor.constraint(equalTo: omniboxContainer.trailingAnchor, constant: -8),
            omnibox.centerYAnchor.constraint(equalTo: omniboxContainer.centerYAnchor),
            
            // Settings button
            settingsButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            settingsButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            settingsButton.widthAnchor.constraint(equalToConstant: 32),
            settingsButton.heightAnchor.constraint(equalToConstant: 32),
            
            // Progress view
            progressView.leadingAnchor.constraint(equalTo: leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: trailingAnchor),
            progressView.bottomAnchor.constraint(equalTo: bottomAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 2),
            
            // Overall height
            heightAnchor.constraint(equalToConstant: 44)
        ])
        
        // Actions
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        forwardButton.addTarget(self, action: #selector(forwardTapped), for: .touchUpInside)
        reloadButton.addTarget(self, action: #selector(reloadTapped), for: .touchUpInside)
        homeButton.addTarget(self, action: #selector(homeTapped), for: .touchUpInside)
        settingsButton.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside)
        
        omnibox.delegate = self
        omnibox.addTarget(self, action: #selector(omniboxEditingChanged), for: .editingChanged)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(omniboxContainerTapped))
        omniboxContainer.addGestureRecognizer(tapGesture)
    }
    
    // MARK: - Public Methods
    
    func updateURL(_ urlString: String?) {
        guard !omnibox.isFirstResponder else { return }
        omnibox.text = urlString
        updateLockIcon(urlString: urlString)
    }
    
    func updateProgress(_ progress: Float, isLoading: Bool) {
        if isLoading {
            progressView.isHidden = false
            progressView.setProgress(progress, animated: true)
        } else {
            progressView.setProgress(1.0, animated: false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.progressView.isHidden = true
                self.progressView.setProgress(0, animated: false)
            }
        }
    }
    
    func updateNavigationButtons(canGoBack: Bool, canGoForward: Bool) {
        backButton.isEnabled = canGoBack
        backButton.tintColor = canGoBack ? UIColor(hex: 0x5F6368) : UIColor(hex: 0xCCCCCC)
        
        forwardButton.isEnabled = canGoForward
        forwardButton.tintColor = canGoForward ? UIColor(hex: 0x5F6368) : UIColor(hex: 0xCCCCCC)
    }
    
    // MARK: - Private Methods
    
    private func updateLockIcon(urlString: String?) {
        if let urlStr = urlString, urlStr.hasPrefix("https://") {
            lockIcon.image = UIImage(systemName: "lock.fill")
            lockIcon.tintColor = UIColor(hex: 0x5F6368)
        } else {
            lockIcon.image = UIImage(systemName: "magnifyingglass")
            lockIcon.tintColor = UIColor(hex: 0x5F6368)
        }
    }
    
    // MARK: - Actions
    
    @objc private func backTapped() {
        delegate?.navigationBarDidTapBack(self)
    }
    
    @objc private func forwardTapped() {
        delegate?.navigationBarDidTapForward(self)
    }
    
    @objc private func reloadTapped() {
        delegate?.navigationBarDidTapReload(self)
    }
    
    @objc private func homeTapped() {
        delegate?.navigationBarDidTapHome(self)
    }
    
    @objc private func settingsTapped() {
        delegate?.navigationBarDidTapSettings(self)
    }
    
    @objc private func omniboxContainerTapped() {
        omnibox.becomeFirstResponder()
    }
    
    @objc private func omniboxEditingChanged() {
        // Could add search suggestions here
    }
}

// MARK: - UITextFieldDelegate

extension NavigationBarView: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        // Show full URL when editing
        if let url = textField.text, let urlObj = URL(string: url), urlObj.scheme != nil {
            textField.text = url
        }
        delegate?.navigationBarDidBeginEditing(self)
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        delegate?.navigationBarDidEndEditing(self)
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard let text = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else { return false }
        
        delegate?.navigationBar(self, didSubmitText: text)
        textField.resignFirstResponder()
        return false
    }
}
