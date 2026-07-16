import UIKit
import WebKit

class BrowserViewController: UIViewController {
    
    // MARK: - Properties
    private var webView: WKWebView!
    private var navigationBar: NavigationBarView!
    private var settingsOverlay: SettingsView!
    private var downloadIndicator: UILabel!
    private var isSettingsVisible = false
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .dark // Force dark mode for all system UI
        setupWebView()
        setupUI()
        setupDelegates()
        setupObservers()
        applyAdBlocker()
        
        // Load Google on start
        webView.load(URLRequest(url: URL(string: "https://www.google.com")!))
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        CookieManager.shared.saveCookies()
    }
    
    // MARK: - Setup
    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.preferences.javaScriptEnabled = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        
        // Apply ad blocking
        AdBlocker.shared.apply(to: config)
        
        webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = false // We use custom gestures
        webView.navigationDelegate = self
        webView.uiDelegate = self
        
        // Custom edge swipe gestures for back/forward
        let swipeRight = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(handleSwipeRight))
        swipeRight.edges = .left
        view.addGestureRecognizer(swipeRight)
        
        let swipeLeft = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(handleSwipeLeft))
        swipeLeft.edges = .right
        view.addGestureRecognizer(swipeLeft)
        
        // Make WKWebView's scroll view pan gesture wait for our edge swipes to fail
        if let scrollGestures = webView.scrollView.gestureRecognizers {
            for gesture in scrollGestures {
                if gesture is UIPanGestureRecognizer {
                    gesture.require(toFail: swipeRight)
                    gesture.require(toFail: swipeLeft)
                }
            }
        }
        
        // Use modern default user agent (always up to date)
        webView.addObserver(self, forKeyPath: "title", options: [.new], context: nil)
        webView.addObserver(self, forKeyPath: "loading", options: [.new], context: nil)
        webView.addObserver(self, forKeyPath: "estimatedProgress", options: [.new], context: nil)
        webView.addObserver(self, forKeyPath: "URL", options: [.new], context: nil)
        webView.addObserver(self, forKeyPath: "canGoBack", options: [.new], context: nil)
        webView.addObserver(self, forKeyPath: "canGoForward", options: [.new], context: nil)
    }
    
    private func setupUI() {
        view.backgroundColor = UIColor(hex: 0x1C1C1E) // Dark background
        
        // Navigation Bar
        navigationBar = NavigationBarView()
        navigationBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(navigationBar)
        
        // WebView
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        
        // Download Indicator
        downloadIndicator = UILabel()
        downloadIndicator.font = .systemFont(ofSize: 12, weight: .medium)
        downloadIndicator.textColor = UIColor(hex: 0x6CB4FF)
        downloadIndicator.textAlignment = .center
        downloadIndicator.backgroundColor = UIColor(hex: 0x2C2C2E)
        downloadIndicator.layer.cornerRadius = 4
        downloadIndicator.clipsToBounds = true
        downloadIndicator.isHidden = true
        downloadIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(downloadIndicator)
        
        // Settings Overlay
        settingsOverlay = SettingsView()
        settingsOverlay.isHidden = true
        settingsOverlay.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(settingsOverlay)
        
        NSLayoutConstraint.activate([
            navigationBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navigationBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navigationBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            webView.topAnchor.constraint(equalTo: navigationBar.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
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
        navigationBar.delegate = self
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
        NotificationCenter.default.addObserver(self, selector: #selector(appWillResignActive), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    private func applyAdBlocker() {
        AdBlocker.shared.reloadRules()
    }
    
    // MARK: - UI Updates
    private func updateUI() {
        navigationBar.updateURL(webView.url?.absoluteString)
        navigationBar.updateProgress(Float(webView.estimatedProgress), isLoading: webView.isLoading)
    }
    
    private func toggleSettings() {
        isSettingsVisible.toggle()
        if isSettingsVisible {
            settingsOverlay.isHidden = false
            UIView.animate(withDuration: 0.25) { self.settingsOverlay.alpha = 1 }
        } else {
            UIView.animate(withDuration: 0.25, animations: { self.settingsOverlay.alpha = 0 }) { _ in self.settingsOverlay.isHidden = true }
        }
    }
    
    private func showClearDataAlert() {
        let alert = UIAlertController(title: "Clear Browsing Data", message: "This will clear all cookies, cache, and browsing data.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Clear All", style: .destructive) { [weak self] _ in
            CookieManager.shared.clearAllData {
                DispatchQueue.main.async {
                    let done = UIAlertController(title: "Done", message: "All data cleared.", preferredStyle: .alert)
                    done.addAction(UIAlertAction(title: "OK", style: .default))
                    self?.present(done, animated: true)
                }
            }
        })
        present(alert, animated: true)
    }
    
    // MARK: - Navigation Helper
    private func navigateTo(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        if let url = URL(string: trimmed), url.scheme != nil, trimmed.contains(".") {
            // Valid URL - load directly (no DoH sync call which blocks main thread)
            webView.load(URLRequest(url: url))
        } else {
            // Search on Google
            let allowedChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~ "))
            let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: allowedChars) ?? trimmed
            let searchQuery = encoded.replacingOccurrences(of: " ", with: "+")
            guard let searchURL = URL(string: "https://www.google.com/search?q=\(searchQuery)") else { return }
            webView.load(URLRequest(url: searchURL))
        }
    }
    
    // MARK: - KVO
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        guard let webView = object as? WKWebView, webView == self.webView else { return }
        
        switch keyPath {
        case "title":
            break // Title shown in navigation bar via URL
        case "loading":
            if !webView.isLoading {
                CookieManager.shared.saveCookies()
            }
        case "estimatedProgress":
            break
        case "URL":
            break
        case "canGoBack", "canGoForward":
            break
        default:
            break
        }
        updateUI()
    }
    
    deinit {
        webView?.removeObserver(self, forKeyPath: "title")
        webView?.removeObserver(self, forKeyPath: "loading")
        webView?.removeObserver(self, forKeyPath: "estimatedProgress")
        webView?.removeObserver(self, forKeyPath: "URL")
        webView?.removeObserver(self, forKeyPath: "canGoBack")
        webView?.removeObserver(self, forKeyPath: "canGoForward")
    }
    
    @objc private func appWillResignActive() { CookieManager.shared.saveCookies() }
    @objc private func appDidBecomeActive() {
        // Safe cookie restore - won't crash on corrupted data
        CookieManager.shared.restoreCookies()
    }
    
    // MARK: - Swipe Gestures
    @objc private func handleSwipeRight(_ gesture: UIScreenEdgePanGestureRecognizer) {
        guard gesture.state == .ended, webView.canGoBack else { return }
        DispatchQueue.main.async {
            self.webView.goBack()
        }
    }
    
    @objc private func handleSwipeLeft(_ gesture: UIScreenEdgePanGestureRecognizer) {
        guard gesture.state == .ended, webView.canGoForward else { return }
        DispatchQueue.main.async {
            self.webView.goForward()
        }
    }
}

// MARK: - NavigationBarViewDelegate
extension BrowserViewController: NavigationBarViewDelegate {
    func navigationBarDidTapSettings(_ navBar: NavigationBarView) {
        toggleSettings()
    }
    func navigationBar(_ navBar: NavigationBarView, didSubmitText text: String) {
        navigateTo(text: text)
        updateUI()
    }
    func navigationBarDidBeginEditing(_ navBar: NavigationBarView) {}
    func navigationBarDidEndEditing(_ navBar: NavigationBarView) { updateUI() }
}

// MARK: - WKNavigationDelegate
extension BrowserViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.allow); return }
        if url.scheme == "http" || url.scheme == "https" || url.scheme == "about" {
            decisionHandler(.allow)
        } else {
            decisionHandler(.cancel)
        }
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        // Only check main frame responses for downloads (not subresources like images, css, js)
        guard navigationResponse.isForMainFrame, let url = navigationResponse.response.url else {
            decisionHandler(.allow)
            return
        }
        if DownloadManager.shared.isDownloadableURL(url, response: navigationResponse.response) {
            let filename = DownloadManager.shared.suggestedFilename(from: navigationResponse.response, url: url)
            DownloadManager.shared.startDownload(from: url, suggestedFilename: filename)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        CookieManager.shared.saveCookies()
        updateUI()
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {}
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {}
}

// MARK: - WKUIDelegate
extension BrowserViewController: WKUIDelegate {
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
            self.webView.load(URLRequest(url: url))
        }
        return nil
    }
    
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        present(alert, animated: true)
    }
}

// MARK: - DownloadManagerDelegate
extension BrowserViewController: DownloadManagerDelegate {
    func downloadManager(_ manager: DownloadManager, didStartDownload fileName: String) {
        DispatchQueue.main.async {
            self.downloadIndicator.isHidden = false
            self.downloadIndicator.text = "Downloading: \(fileName)"
        }
    }
    func downloadManager(_ manager: DownloadManager, didUpdateProgress progress: Float, fileName: String) {
        DispatchQueue.main.async {
            self.downloadIndicator.text = "Downloading: \(fileName) (\(Int(progress * 100))%)"
        }
    }
    func downloadManager(_ manager: DownloadManager, didFinishDownload fileName: String, savedTo: URL) {
        DispatchQueue.main.async {
            self.downloadIndicator.text = "Saved: \(fileName)"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.downloadIndicator.isHidden = true }
            let activityVC = UIActivityViewController(activityItems: [savedTo], applicationActivities: nil)
            self.present(activityVC, animated: true)
        }
    }
    func downloadManager(_ manager: DownloadManager, didFailDownload fileName: String, error: Error) {
        DispatchQueue.main.async {
            self.downloadIndicator.text = "Failed: \(fileName)"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.downloadIndicator.isHidden = true }
        }
    }
}

// MARK: - SettingsViewDelegate
extension BrowserViewController: SettingsViewDelegate {
    func settingsViewDidDismiss(_ settingsView: SettingsView) {
        toggleSettings()
    }
}
