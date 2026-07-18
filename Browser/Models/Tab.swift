import Foundation
import WebKit
import UIKit

class Tab {
    let id = UUID()
    let webView: WKWebView
    var title: String = "New Tab"
    var url: String = ""
    var pendingURL: URL?
    var snapshot: UIImage?
    
    init(webView: WKWebView) {
        self.webView = webView
    }
}
