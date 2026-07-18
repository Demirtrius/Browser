import Foundation
import WebKit

class TabManager {
    private(set) var tabs: [Tab] = []
    var activeTabId: UUID?
    
    var activeTab: Tab? {
        guard let id = activeTabId else { return nil }
        return tabs.first { t in t.id == id }
    }
    
    var tabCount: Int { tabs.count }
    
    func createWebViewConfig() -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        AdBlocker.shared.apply(to: config)
        return config
    }
    
    func addTab(url: URL? = nil) -> Tab {
        let config = createWebViewConfig()
        let webView = WKWebView(frame: .zero, configuration: config)
        let tab = Tab(webView: webView)
        tab.pendingURL = url
        tabs.append(tab)
        activeTabId = tab.id
        // Don't load here — let the view controller set delegates first
        return tab
    }
    
    func closeTab(id: UUID) {
        guard let index = tabs.firstIndex(where: { t in t.id == id }) else { return }
        tabs.remove(at: index)
        
        if tabs.isEmpty {
            _ = addTab()
            return
        }
        
        if activeTabId == id {
            let newIndex = min(index, tabs.count - 1)
            activeTabId = tabs[newIndex].id
        }
    }
    
    func switchToTab(id: UUID) {
        guard tabs.contains(where: { t in t.id == id }) else { return }
        activeTabId = id
    }
}
