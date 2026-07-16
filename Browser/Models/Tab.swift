import UIKit
import WebKit

class Tab: NSObject {
    let id: UUID
    var title: String
    var url: URL?
    var favicon: UIImage?
    var isLoading: Bool = false
    var progress: Double = 0.0
    let webView: WKWebView
    
    var canGoBack: Bool { webView.canGoBack }
    var canGoForward: Bool { webView.canGoForward }
    
    init(configuration: WKWebViewConfiguration, url: URL? = nil) {
        self.id = UUID()
        self.title = "New Tab"
        self.url = url
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        self.webView = webView
        
        super.init()
        
        webView.navigationDelegate = nil // Will be set by WebViewController
        webView.uiDelegate = nil
        
        if let url = url {
            webView.load(URLRequest(url: url))
        }
    }
    
    func loadURL(_ url: URL) {
        self.url = url
        webView.load(URLRequest(url: url))
    }
    
    func updateTitle(_ title: String?) {
        self.title = title?.isEmpty == false ? title! : "New Tab"
    }
    
    func updateFavicon(_ image: UIImage?) {
        self.favicon = image
    }
}
