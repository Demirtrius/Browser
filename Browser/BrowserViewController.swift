import UIKit
import WebKit

class BrowserViewController: UIViewController, UITextFieldDelegate, WKNavigationDelegate {
    
    private var webView: WKWebView!
    private var textField: UITextField!
    private var spinner: UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .dark
        view.backgroundColor = UIColor(hex: 0x1C1C1E)
        
        // Text field at top
        textField = UITextField()
        textField.font = .systemFont(ofSize: 14)
        textField.textColor = .white
        textField.backgroundColor = UIColor(hex: 0x3A3A3C)
        textField.borderStyle = .none
        textField.layer.cornerRadius = 8
        textField.keyboardAppearance = .dark
        textField.returnKeyType = .go
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.clearButtonMode = .never
        textField.delegate = self
        textField.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(textField)
        
        // Loading spinner (right side of address bar)
        spinner = UIActivityIndicatorView(style: .medium)
        spinner.color = UIColor(hex: 0x6CB4FF)
        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(spinner)
        
        // WebView
        let config = WKWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        
        NSLayoutConstraint.activate([
            textField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            textField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            textField.trailingAnchor.constraint(equalTo: spinner.leadingAnchor, constant: -8),
            textField.heightAnchor.constraint(equalToConstant: 36),
            spinner.centerYAnchor.constraint(equalTo: textField.centerYAnchor),
            spinner.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            webView.topAnchor.constraint(equalTo: textField.bottomAnchor, constant: 8),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        
        // Edge swipes
        let back = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(swipeBack))
        back.edges = .left
        view.addGestureRecognizer(back)
        let fwd = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(swipeFwd))
        fwd.edges = .right
        view.addGestureRecognizer(fwd)
        
        // Lifecycle observers
        NotificationCenter.default.addObserver(self, selector: #selector(onBackground), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        
        // Check if app crashed last time
        if UserDefaults.standard.bool(forKey: "appWasActive") {
            // App crashed while active - clear web data to prevent repeated crashes
            WKWebsiteDataStore.default().removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: Date(timeIntervalSince1970: 0)) {}
        }
        UserDefaults.standard.set(true, forKey: "appWasActive")
        
        webView.load(URLRequest(url: URL(string: "https://www.google.com")!))
    }
    
    @objc private func onBackground() {
        UserDefaults.standard.set(true, forKey: "appWasActive")
    }
    
    @objc private func onForeground() {
        UserDefaults.standard.set(false, forKey: "appWasActive")
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
    
    // MARK: - UITextFieldDelegate
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard let text = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            textField.resignFirstResponder()
            return true
        }
        
        let url = parseURL(text)
        webView.load(URLRequest(url: url))
        textField.resignFirstResponder()
        return true
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        textField.selectAll(nil)
    }
    
    // MARK: - URL Parsing
    private func parseURL(_ text: String) -> URL {
        // Already has scheme
        if text.hasPrefix("http://") || text.hasPrefix("https://") {
            if let url = URL(string: text) { return url }
        }
        
        // IP address pattern (e.g., 192.168.1.1 or 192.168.1.1:8080)
        let ipPattern = #"^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}(:\d+)?$"#
        if text.range(of: ipPattern, options: .regularExpression) != nil {
            return URL(string: "http://" + text) ?? URL(string: "https://www.google.com/search?q=" + text)!
        }
        
        // Domain with dots and no spaces = URL
        if text.contains(".") && !text.contains(" ") {
            return URL(string: "https://" + text) ?? URL(string: "https://www.google.com/search?q=" + text)!
        }
        
        // Otherwise = Google search
        let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text
        return URL(string: "https://www.google.com/search?q=" + encoded)!
    }
    
    // MARK: - WKNavigationDelegate
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        textField.text = webView.url?.absoluteString
        spinner.stopAnimating()
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        spinner.startAnimating()
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        spinner.stopAnimating()
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        spinner.stopAnimating()
    }
}
