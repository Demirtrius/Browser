import Foundation
import WebKit

class TabManager {
    private(set) var tabs: [Tab] = []
    var activeTabId: UUID?
    
    var activeTab: Tab? {
        guard let id = activeTabId else { return nil }
        return tabs.first { .id == id }
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
        tabs.append(tab)
        activeTabId = tab.id
        
        let loadURL = url ?? URL(string: "https://www.google.com")!
        webView.load(URLRequest(url: loadURL))
        
        return tab
    }
    
    func closeTab(id: UUID) {
        guard let index = tabs.firstIndex(where: { .id == id }) else { return }
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
        guard tabs.contains(where: { .id == id }) else { return }
        activeTabId = id
    }
}
