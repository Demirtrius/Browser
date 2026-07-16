import UIKit
import WebKit

class BrowserViewController: UIViewController, UITextFieldDelegate, WKNavigationDelegate {
    
    private var webView: WKWebView!
    private var textField: UITextField!
    
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
        textField.clearButtonMode = .whileEditing
        textField.placeholder = "Search or enter URL"
        textField.delegate = self
        textField.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(textField)
        
        // WebView
        let config = WKWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        
        NSLayoutConstraint.activate([
            textField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            textField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            textField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            textField.heightAnchor.constraint(equalToConstant: 36),
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
        
        webView.load(URLRequest(url: URL(string: "https://www.google.com")!))
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
        
        var urlString = text
        if !text.hasPrefix("http://") && !text.hasPrefix("https://") {
            if text.contains(".") && !text.contains(" ") {
                urlString = "https://" + text
            } else {
                let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text
                urlString = "https://www.google.com/search?q=" + encoded
            }
        }
        
        if let url = URL(string: urlString) {
            webView.load(URLRequest(url: url))
        }
        
        textField.resignFirstResponder()
        return true
    }
    
    // MARK: - WKNavigationDelegate
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let url = webView.url {
            textField.text = url.absoluteString
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {}
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {}
}
