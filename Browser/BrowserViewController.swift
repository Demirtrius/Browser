import UIKit
import WebKit

class BrowserViewController: UIViewController {
    
    private var webView: WKWebView!
    private var navBar: NavigationBarView!
    private var settingsView: SettingsView!
    private var showingSettings = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .dark
        view.backgroundColor = UIColor(hex: 0x1C1C1E)
        
        // WebView
        let config = WKWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = false
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        
        // Nav bar
        navBar = NavigationBarView()
        navBar.delegate = self
        navBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(navBar)
        
        // Settings
        settingsView = SettingsView()
        settingsView.isHidden = true
        settingsView.delegate = self
        settingsView.onClearData = { [weak self] in self?.clearData() }
        settingsView.onSettingsChanged = {}
        settingsView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(settingsView)
        
        // Edge swipes
        let back = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(swipeBack))
        back.edges = .left
        view.addGestureRecognizer(back)
        let fwd = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(swipeFwd))
        fwd.edges = .right
        view.addGestureRecognizer(fwd)
        
        // Layout
        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.topAnchor.constraint(equalTo: navBar.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            settingsView.topAnchor.constraint(equalTo: view.topAnchor),
            settingsView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            settingsView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            settingsView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        
        // Save cookies on background
        NotificationCenter.default.addObserver(self, selector: #selector(save), name: UIApplication.willResignActiveNotification, object: nil)
        
        // Load Google
        webView.load(URLRequest(url: URL(string: "https://www.google.com")!))
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        CookieManager.shared.saveCookies()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func swipeBack(_ g: UIScreenEdgePanGestureRecognizer) {
        guard g.state == .ended, webView.canGoBack else { return }
        webView.goBack()
    }
    
    @objc private func swipeFwd(_ g: UIScreenEdgePanGestureRecognizer) {
        guard g.state == .ended, webView.canGoForward else { return }
        webView.goForward()
    }
    
    @objc private func save() {
        CookieManager.shared.saveCookies()
    }
    
    private func go(_ text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        var urlString = t
        if !t.hasPrefix("http://") && !t.hasPrefix("https://") {
            if t.contains(".") && !t.contains(" ") {
                urlString = "https://" + t
            } else {
                let q = t.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? t
                urlString = "https://www.google.com/search?q=" + q
            }
        }
        if let url = URL(string: urlString) {
            webView.load(URLRequest(url: url))
        }
    }
    
    private func refreshUI() {
        navBar.updateURL(webView.url?.absoluteString)
        navBar.updateProgress(Float(webView.estimatedProgress), isLoading: webView.isLoading)
    }
    
    private func toggleSettings() {
        showingSettings = !showingSettings
        settingsView.isHidden = !showingSettings
        UIView.animate(withDuration: 0.2) { self.settingsView.alpha = self.showingSettings ? 1 : 0 }
    }
    
    private func clearData() {
        let a = UIAlertController(title: "Clear", message: "Clear all data?", preferredStyle: .alert)
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

extension BrowserViewController: NavigationBarViewDelegate {
    func navigationBarDidTapSettings(_ navBar: NavigationBarView) { toggleSettings() }
    func navigationBar(_ navBar: NavigationBarView, didSubmitText text: String) { go(text) }
    func navigationBarDidBeginEditing(_ navBar: NavigationBarView) {}
    func navigationBarDidEndEditing(_ navBar: NavigationBarView) { refreshUI() }
}

extension BrowserViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        CookieManager.shared.saveCookies()
        refreshUI()
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {}
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {}
}

extension BrowserViewController: WKUIDelegate {
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
            self.webView.load(URLRequest(url: url))
        }
        return nil
    }
}

extension BrowserViewController: SettingsViewDelegate {
    func settingsViewDidDismiss(_ settingsView: SettingsView) { toggleSettings() }
}
