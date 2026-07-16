import UIKit
import WebKit

class BrowserViewController: UIViewController {
    
    private var webView: WKWebView!
    private var navigationBar: NavigationBarView!
    private var settingsOverlay: SettingsView!
    private var isSettingsVisible = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .dark
        view.backgroundColor = UIColor(hex: 0x1C1C1E)
        
        setupWebView()
        setupNavigationBar()
        setupSettings()
        
        webView.load(URLRequest(url: URL(string: "https://www.google.com")!))
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        CookieManager.shared.saveCookies()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup
    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = false
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        
        // Edge swipe gestures
        let backSwipe = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(onBackSwipe))
        backSwipe.edges = .left
        view.addGestureRecognizer(backSwipe)
        
        let fwdSwipe = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(onFwdSwipe))
        fwdSwipe.edges = .right
        view.addGestureRecognizer(fwdSwipe)
        
        // Layout
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 44),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        
        // App lifecycle
        NotificationCenter.default.addObserver(self, selector: #selector(onResign), name: UIApplication.willResignActiveNotification, object: nil)
    }
    
    private func setupNavigationBar() {
        navigationBar = NavigationBarView()
        navigationBar.delegate = self
        navigationBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(navigationBar)
        
        NSLayoutConstraint.activate([
            navigationBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navigationBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navigationBar.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    private func setupSettings() {
        settingsOverlay = SettingsView()
        settingsOverlay.isHidden = true
        settingsOverlay.delegate = self
        settingsOverlay.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(settingsOverlay)
        
        settingsOverlay.onClearData = { [weak self] in
            self?.showClearAlert()
        }
        settingsOverlay.onSettingsChanged = {}
        
        NSLayoutConstraint.activate([
            settingsOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            settingsOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            settingsOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            settingsOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    // MARK: - Actions
    @objc private func onBackSwipe(_ g: UIScreenEdgePanGestureRecognizer) {
        guard g.state == .ended, webView.canGoBack else { return }
        webView.goBack()
    }
    
    @objc private func onFwdSwipe(_ g: UIScreenEdgePanGestureRecognizer) {
        guard g.state == .ended, webView.canGoForward else { return }
        webView.goForward()
    }
    
    @objc private func onResign() {
        CookieManager.shared.saveCookies()
    }
    
    private func navigate(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        
        if let url = URL(string: t), url.scheme != nil, t.contains(".") {
            webView.load(URLRequest(url: url))
        } else {
            let chars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~ "))
            let q = (t.addingPercentEncoding(withAllowedCharacters: chars) ?? t).replacingOccurrences(of: " ", with: "+")
            if let url = URL(string: "https://www.google.com/search?q=\(q)") {
                webView.load(URLRequest(url: url))
            }
        }
    }
    
    private func refreshBar() {
        navigationBar.updateURL(webView.url?.absoluteString)
        navigationBar.updateProgress(Float(webView.estimatedProgress), isLoading: webView.isLoading)
    }
    
    private func toggleSettings() {
        isSettingsVisible.toggle()
        settingsOverlay.isHidden = !isSettingsVisible
        if isSettingsVisible {
            UIView.animate(withDuration: 0.2) { self.settingsOverlay.alpha = 1 }
        } else {
            UIView.animate(withDuration: 0.2) { self.settingsOverlay.alpha = 0 }
        }
    }
    
    private func showClearAlert() {
        let a = UIAlertController(title: "Clear Data", message: "Clear all cookies and data?", preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        a.addAction(UIAlertAction(title: "Clear", style: .destructive) { [weak self] _ in
            CookieManager.shared.clearAllData {
                DispatchQueue.main.async {
                    self?.webView.load(URLRequest(url: URL(string: "https://www.google.com")!))
                }
            }
        })
        present(a, animated: true)
    }
}

// MARK: - NavigationBarViewDelegate
extension BrowserViewController: NavigationBarViewDelegate {
    func navigationBarDidTapSettings(_ navBar: NavigationBarView) { toggleSettings() }
    func navigationBar(_ navBar: NavigationBarView, didSubmitText text: String) { navigate(text); refreshBar() }
    func navigationBarDidBeginEditing(_ navBar: NavigationBarView) {}
    func navigationBarDidEndEditing(_ navBar: NavigationBarView) { refreshBar() }
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
        guard navigationResponse.isForMainFrame, let url = navigationResponse.response.url else {
            decisionHandler(.allow); return
        }
        if DownloadManager.shared.isDownloadableURL(url, response: navigationResponse.response) {
            let fn = DownloadManager.shared.suggestedFilename(from: navigationResponse.response, url: url)
            DownloadManager.shared.startDownload(from: url, suggestedFilename: fn)
            decisionHandler(.cancel); return
        }
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        CookieManager.shared.saveCookies()
        refreshBar()
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
        let a = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        present(a, animated: true)
    }
}

// MARK: - DownloadManagerDelegate
extension BrowserViewController: DownloadManagerDelegate {
    func downloadManager(_ m: DownloadManager, didStartDownload fileName: String) {}
    func downloadManager(_ m: DownloadManager, didUpdateProgress progress: Float, fileName: String) {}
    func downloadManager(_ m: DownloadManager, didFinishDownload fileName: String, savedTo: URL) {
        DispatchQueue.main.async {
            let a = UIActivityViewController(activityItems: [savedTo], applicationActivities: nil)
            self.present(a, animated: true)
        }
    }
    func downloadManager(_ m: DownloadManager, didFailDownload fileName: String, error: Error) {}
}

// MARK: - SettingsViewDelegate
extension BrowserViewController: SettingsViewDelegate {
    func settingsViewDidDismiss(_ settingsView: SettingsView) { toggleSettings() }
}
