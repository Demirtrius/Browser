import UIKit
import WebKit

class MainViewController: UIViewController {
    
    private let tabManager = TabManager.shared
    private let webViewController = WebViewController()
    
    private let tabBarView = TabBarView()
    private let navigationBar = NavigationBarView()
    private let webViewContainer = UIView()
    private let settingsOverlay = SettingsView()
    private let downloadIndicator = UILabel()
    
    private var isSettingsVisible = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupDelegates()
        setupObservers()
        applyAdBlocker()
        
        // Setup initial tab
        if let tab = tabManager.activeTab {
            webViewController.setupWebView(for: tab)
            showWebView(for: tab)
            updateUI()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        CookieManager.shared.saveCookies()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        CookieManager.shared.restoreCookies()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .white
        
        // Tab Bar
        view.addSubview(tabBarView)
        tabBarView.translatesAutoresizingMaskIntoConstraints = false
        
        // Navigation Bar
        view.addSubview(navigationBar)
        navigationBar.translatesAutoresizingMaskIntoConstraints = false
        
        // WebView Container
        view.addSubview(webViewContainer)
        webViewContainer.translatesAutoresizingMaskIntoConstraints = false
        webViewContainer.clipsToBounds = true
        
        // Download Indicator
        downloadIndicator.font = .systemFont(ofSize: 12, weight: .medium)
        downloadIndicator.textColor = UIColor(hex: 0x4285F4)
        downloadIndicator.textAlignment = .center
        downloadIndicator.backgroundColor = UIColor(hex: 0xF1F1F1)
        downloadIndicator.layer.cornerRadius = 4
        downloadIndicator.clipsToBounds = true
        downloadIndicator.isHidden = true
        downloadIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(downloadIndicator)
        
        // Settings Overlay
        settingsOverlay.frame = view.bounds
        settingsOverlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        settingsOverlay.isHidden = true
        settingsOverlay.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(settingsOverlay)
        
        NSLayoutConstraint.activate([
            tabBarView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tabBarView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabBarView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            navigationBar.topAnchor.constraint(equalTo: tabBarView.bottomAnchor),
            navigationBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navigationBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            webViewContainer.topAnchor.constraint(equalTo: navigationBar.bottomAnchor),
            webViewContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webViewContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webViewContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            downloadIndicator.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            downloadIndicator.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            downloadIndicator.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            downloadIndicator.heightAnchor.constraint(equalToConstant: 28),
            
            settingsOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            settingsOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            settingsOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            settingsOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupDelegates() {
        tabBarView.delegate = self
        navigationBar.delegate = self
        tabManager.delegate = self
        DownloadManager.shared.delegate = self
        settingsOverlay.delegate = self
        
        settingsOverlay.onClearData = { [weak self] in
            self?.showClearDataAlert()
        }
        
        settingsOverlay.onSettingsChanged = { [weak self] in
            self?.applyAdBlocker()
        }
    }
    
    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    private func applyAdBlocker() {
        // Ad blocker is applied to the shared process pool configuration
        // New tabs will get the updated rules
        AdBlocker.shared.reloadRules()
    }
    
    // MARK: - UI Updates
    
    private func updateUI() {
        tabBarView.updateTabs(tabs: tabManager.tabs, activeIndex: tabManager.activeTabIndex)
        
        guard let tab = tabManager.activeTab else { return }
        
        navigationBar.updateURL(tab.url?.absoluteString)
        navigationBar.updateNavigationButtons(canGoBack: tab.canGoBack, canGoForward: tab.canGoForward)
        navigationBar.updateProgress(Float(tab.progress), isLoading: tab.isLoading)
    }
    
    private func showWebView(for tab: Tab) {
        // Remove all existing web views
        webViewContainer.subviews.forEach { $0.removeFromSuperview() }
        
        // Add the tab's web view
        let webView = tab.webView
        webView.translatesAutoresizingMaskIntoConstraints = false
        webViewContainer.addSubview(webView)
        
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: webViewContainer.topAnchor),
            webView.leadingAnchor.constraint(equalTo: webViewContainer.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: webViewContainer.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: webViewContainer.bottomAnchor)
        ])
    }
    
    private func toggleSettings() {
        isSettingsVisible.toggle()
        
        if isSettingsVisible {
            settingsOverlay.isHidden = false
            UIView.animate(withDuration: 0.25) {
                self.settingsOverlay.alpha = 1
            }
        } else {
            UIView.animate(withDuration: 0.25, animations: {
                self.settingsOverlay.alpha = 0
            }) { _ in
                self.settingsOverlay.isHidden = true
            }
        }
    }
    
    private func showClearDataAlert() {
        let alert = UIAlertController(
            title: "Clear Browsing Data",
            message: "This will clear all cookies, cache, and browsing data. This action cannot be undone.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Clear All", style: .destructive) { _ in
            CookieManager.shared.clearAllData {
                DispatchQueue.main.async {
                    let successAlert = UIAlertController(
                        title: "Done",
                        message: "All browsing data has been cleared.",
                        preferredStyle: .alert
                    )
                    successAlert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(successAlert, animated: true)
                }
            }
        })
        
        present(alert, animated: true)
    }
    
    // MARK: - App Lifecycle
    
    @objc private func appWillResignActive() {
        CookieManager.shared.saveCookies()
    }
    
    @objc private func appDidBecomeActive() {
        CookieManager.shared.restoreCookies()
    }
}

// MARK: - TabBarViewDelegate

extension MainViewController: TabBarViewDelegate {
    func tabBarView(_ tabBarView: TabBarView, didSelectTabAt index: Int) {
        tabManager.switchTab(id: tabManager.tabs[index].id)
        
        if let tab = tabManager.activeTab {
            showWebView(for: tab)
            webViewController.setupWebView(for: tab)
        }
        updateUI()
    }
    
    func tabBarView(_ tabBarView: TabBarView, didCloseTabAt index: Int) {
        let tab = tabManager.tabs[index]
        webViewController.removeObservers(for: tab)
        tabManager.closeTab(id: tab.id)
        
        if let tab = tabManager.activeTab {
            showWebView(for: tab)
            webViewController.setupWebView(for: tab)
        }
        updateUI()
    }
    
    func tabBarViewDidTapNewTab(_ tabBarView: TabBarView) {
        let tab = tabManager.addTab(url: URL(string: BrowserSettings.shared.homepage))
        webViewController.setupWebView(for: tab)
        showWebView(for: tab)
        updateUI()
    }
}

// MARK: - NavigationBarViewDelegate

extension MainViewController: NavigationBarViewDelegate {
    func navigationBarDidTapBack(_ navBar: NavigationBarView) {
        tabManager.activeTab?.webView.goBack()
        updateUI()
    }
    
    func navigationBarDidTapForward(_ navBar: NavigationBarView) {
        tabManager.activeTab?.webView.goForward()
        updateUI()
    }
    
    func navigationBarDidTapReload(_ navBar: NavigationBarView) {
        tabManager.activeTab?.webView.reload()
        updateUI()
    }
    
    func navigationBarDidTapHome(_ navBar: NavigationBarView) {
        guard let url = URL(string: BrowserSettings.shared.homepage) else { return }
        tabManager.activeTab?.loadURL(url)
        updateUI()
    }
    
    func navigationBarDidTapSettings(_ navBar: NavigationBarView) {
        toggleSettings()
    }
    
    func navigationBar(_ navBar: NavigationBarView, didSubmitText text: String) {
        guard let tab = tabManager.activeTab else { return }
        webViewController.navigateToURL(text, in: tab)
        updateUI()
    }
    
    func navigationBarDidBeginEditing(_ navBar: NavigationBarView) {
        // Could show search suggestions
    }
    
    func navigationBarDidEndEditing(_ navBar: NavigationBarView) {
        updateUI()
    }
}

// MARK: - TabManagerDelegate

extension MainViewController: TabManagerDelegate {
    func tabManagerDidUpdateTabs(_ tabManager: TabManager) {
        DispatchQueue.main.async { [weak self] in
            self?.updateUI()
        }
    }
    
    func tabManagerDidSwitchTab(_ tabManager: TabManager, tab: Tab) {
        DispatchQueue.main.async { [weak self] in
            self?.showWebView(for: tab)
            self?.updateUI()
        }
    }
    
    func tabManagerDidUpdateTitle(_ tabManager: TabManager, tab: Tab) {
        DispatchQueue.main.async { [weak self] in
            self?.updateUI()
        }
    }
    
    func tabManagerDidStartLoading(_ tabManager: TabManager, tab: Tab) {
        DispatchQueue.main.async { [weak self] in
            self?.updateUI()
        }
    }
    
    func tabManagerDidFinishLoading(_ tabManager: TabManager, tab: Tab) {
        DispatchQueue.main.async { [weak self] in
            self?.updateUI()
        }
    }
    
    func tabManagerDidFailLoading(_ tabManager: TabManager, tab: Tab, error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.updateUI()
        }
    }
}

// MARK: - DownloadManagerDelegate

extension MainViewController: DownloadManagerDelegate {
    func downloadManager(_ manager: DownloadManager, didStartDownload fileName: String) {
        DispatchQueue.main.async {
            self.downloadIndicator.isHidden = false
            self.downloadIndicator.text = "Downloading: \(fileName)"
        }
    }
    
    func downloadManager(_ manager: DownloadManager, didUpdateProgress progress: Float, fileName: String) {
        DispatchQueue.main.async {
            let percent = Int(progress * 100)
            self.downloadIndicator.text = "Downloading: \(fileName) (\(percent)%)"
        }
    }
    
    func downloadManager(_ manager: DownloadManager, didFinishDownload fileName: String, savedTo: URL) {
        DispatchQueue.main.async {
            self.downloadIndicator.text = "Saved: \(fileName)"
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.downloadIndicator.isHidden = true
            }
            
            // Show share sheet
            let activityVC = UIActivityViewController(activityItems: [savedTo], applicationActivities: nil)
            self.present(activityVC, animated: true)
        }
    }
    
    func downloadManager(_ manager: DownloadManager, didFailDownload fileName: String, error: Error) {
        DispatchQueue.main.async {
            self.downloadIndicator.text = "Failed: \(fileName)"
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.downloadIndicator.isHidden = true
            }
        }
    }
}

// MARK: - SettingsViewDelegate

extension MainViewController: SettingsViewDelegate {
    func settingsViewDidDismiss(_ settingsView: SettingsView) {
        toggleSettings()
    }
}
