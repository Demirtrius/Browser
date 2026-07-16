import UIKit
import WebKit

class WebViewController: NSObject {
    
    weak var delegate: TabManagerDelegate?
    
    private let tabManager = TabManager.shared
    
    func setupWebView(for tab: Tab) {
        tab.webView.navigationDelegate = self
        tab.webView.uiDelegate = self
        
        // Set custom user agent (Chrome v67 style)
        tab.webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) CriOS/67.0.3396.87 Mobile/15E148 Safari/605.1.15"
        
        // Observe KVO for title and loading
        tab.webView.addObserver(self, forKeyPath: "title", options: [.new], context: nil)
        tab.webView.addObserver(self, forKeyPath: "loading", options: [.new], context: nil)
        tab.webView.addObserver(self, forKeyPath: "estimatedProgress", options: [.new], context: nil)
        tab.webView.addObserver(self, forKeyPath: "URL", options: [.new], context: nil)
        tab.webView.addObserver(self, forKeyPath: "canGoBack", options: [.new], context: nil)
        tab.webView.addObserver(self, forKeyPath: "canGoForward", options: [.new], context: nil)
    }
    
    func removeObservers(for tab: Tab) {
        tab.webView.removeObserver(self, forKeyPath: "title")
        tab.webView.removeObserver(self, forKeyPath: "loading")
        tab.webView.removeObserver(self, forKeyPath: "estimatedProgress")
        tab.webView.removeObserver(self, forKeyPath: "URL")
        tab.webView.removeObserver(self, forKeyPath: "canGoBack")
        tab.webView.removeObserver(self, forKeyPath: "canGoForward")
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard let webView = object as? WKWebView,
              let tab = tabManager.tabs.first(where: { $0.webView === webView }) else { return }
        
        switch keyPath {
        case "title":
            tab.updateTitle(webView.title)
            delegate?.tabManagerDidUpdateTitle(tabManager, tab: tab)
            
        case "loading":
            tab.isLoading = webView.isLoading
            if webView.isLoading {
                delegate?.tabManagerDidStartLoading(tabManager, tab: tab)
            } else {
                delegate?.tabManagerDidFinishLoading(tabManager, tab: tab)
                // Clear history after each page load
                clearHistoryForWebView(webView)
            }
            
        case "estimatedProgress":
            tab.progress = webView.estimatedProgress
            
        case "URL":
            tab.url = webView.url
            
        case "canGoBack", "canGoForward":
            break // Handled by delegate
        }
        
        delegate?.tabManagerDidUpdateTabs(tabManager)
    }
    
    private func clearHistoryForWebView(_ webView: WKWebView) {
        // Clear back/forward list by reloading current page
        // This prevents history accumulation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Clear website data (history) but not cookies
            let dataStore = WKWebsiteDataStore.default()
            let historyTypes: Set<String> = [
                WKWebsiteDataTypeDiskCache,
                WKWebsiteDataTypeMemoryCache
            ]
            let date = Date(timeIntervalSince1970: 0)
            dataStore.removeData(ofTypes: historyTypes, modifiedSince: date) {
                // History cleared
            }
        }
    }
    
    func navigateToURL(_ urlString: String, in tab: Tab) {
        let text = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if it's a URL
        if let url = URL(string: text), url.scheme != nil, text.contains(".") {
            var request = URLRequest(url: url)
            
            // Apply DoH if enabled
            if BrowserSettings.shared.dohEnabled,
               let dohRequest = DoHResolver.shared.createRequest(for: url) {
                request = dohRequest
            }
            
            tab.webView.load(request)
        } else {
            // Search
            if let searchURL = BrowserSettings.shared.searchURL(for: text) {
                tab.webView.load(URLRequest(url: searchURL))
            }
        }
    }
    
    func navigateToURL(_ url: URL, in tab: Tab) {
        var request = URLRequest(url: url)
        
        // Apply DoH if enabled
        if BrowserSettings.shared.dohEnabled,
           let dohRequest = DoHResolver.shared.createRequest(for: url) {
            request = dohRequest
        }
        
        tab.webView.load(request)
    }
}

// MARK: - WKNavigationDelegate

extension WebViewController: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }
        
        // Allow about:blank
        if url.scheme == "about" {
            decisionHandler(.allow)
            return
        }
        
        // Allow http/https
        if url.scheme == "http" || url.scheme == "https" {
            decisionHandler(.allow)
            return
        }
        
        // Block other schemes (tel, mailto, etc.) — could open in system
        decisionHandler(.cancel)
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        guard let url = navigationResponse.response.url else {
            decisionHandler(.allow)
            return
        }
        
        // Check if this is a download
        if DownloadManager.shared.isDownloadableURL(url, response: navigationResponse.response) {
            let filename = DownloadManager.shared.suggestedFilename(from: navigationResponse.response, url: url)
            DownloadManager.shared.startDownload(from: url, suggestedFilename: filename)
            decisionHandler(.cancel)
            return
        }
        
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Clear history after navigation completes
        clearHistoryForWebView(webView)
        
        // Save cookies
        CookieManager.shared.saveCookies()
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("[WebVC] Navigation failed: \(error.localizedDescription)")
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("[WebVC] Provisional navigation failed: \(error.localizedDescription)")
    }
}

// MARK: - WKUIDelegate

extension WebViewController: WKUIDelegate {
    
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        // Handle target="_blank" links — open in new tab
        if navigationAction.targetFrame == nil {
            let newTab = tabManager.addTab()
            if let url = navigationAction.request.url {
                newTab.loadURL(url)
            }
            setupWebView(for: newTab)
            return newTab.webView
        }
        return nil
    }
    
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        
        if let viewController = UIApplication.shared.windows.first?.rootViewController {
            viewController.present(alert, animated: true)
        } else {
            completionHandler()
        }
    }
    
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler(true) })
        
        if let viewController = UIApplication.shared.windows.first?.rootViewController {
            viewController.present(alert, animated: true)
        } else {
            completionHandler(false)
        }
    }
}
