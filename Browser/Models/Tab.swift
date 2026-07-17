import Foundation
import WebKit

class Tab {
    let id = UUID()
    let webView: WKWebView
    var title: String = "New Tab"
    var url: String = ""
    
    init(webView: WKWebView) {
        self.webView = webView
    }
}
