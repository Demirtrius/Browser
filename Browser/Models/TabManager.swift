import Foundation
import WebKit

protocol TabManagerDelegate: AnyObject {
    func tabManagerDidUpdateTabs(_ tabManager: TabManager)
    func tabManagerDidSwitchTab(_ tabManager: TabManager, tab: Tab)
    func tabManagerDidUpdateTitle(_ tabManager: TabManager, tab: Tab)
    func tabManagerDidStartLoading(_ tabManager: TabManager, tab: Tab)
    func tabManagerDidFinishLoading(_ tabManager: TabManager, tab: Tab)
    func tabManagerDidFailLoading(_ tabManager: TabManager, tab: Tab, error: Error)
}

class TabManager {
    static let shared = TabManager()
    
    private(set) var tabs: [Tab] = []
    private(set) var activeTabIndex: Int = 0
    private let configuration: WKWebViewConfiguration
    private let maxTabs = 20
    
    weak var delegate: TabManagerDelegate?
    
    private init() {
        let config = WKWebViewConfiguration()
        config.processPool = WKProcessPool()
        
        // Allow inline media playback
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        
        // JavaScript enabled
        config.preferences.javaScriptEnabled = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        
        // Set Chrome v67-like user agent
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        
        self.configuration = config
        
        // Restore cookies
        CookieManager.shared.restoreCookies()
        
        // Start with one tab
        addTab(url: URL(string: BrowserSettings.shared.homepage))
    }
    
    var activeTab: Tab? {
        guard activeTabIndex >= 0 && activeTabIndex < tabs.count else { return nil }
        return tabs[activeTabIndex]
    }
    
    var configuration_copy: WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.processPool = configuration.processPool
        config.allowsInlineMediaPlayback = configuration.allowsInlineMediaPlayback
        config.mediaTypesRequiringUserActionForPlayback = configuration.mediaTypesRequiringUserActionForPlayback
        config.preferences.javaScriptEnabled = configuration.preferences.javaScriptEnabled
        config.preferences.javaScriptCanOpenWindowsAutomatically = configuration.preferences.javaScriptCanOpenWindowsAutomatically
        config.defaultWebpagePreferences.allowsContentJavaScript = configuration.defaultWebpagePreferences.allowsContentJavaScript
        return config
    }
    
    @discardableResult
    func addTab(url: URL? = nil) -> Tab {
        if tabs.count >= maxTabs {
            // Close oldest tab
            closeTab(id: tabs[0].id)
        }
        
        let tab = Tab(configuration: configuration, url: url)
        tabs.append(tab)
        activeTabIndex = tabs.count - 1
        
        delegate?.tabManagerDidUpdateTabs(self)
        delegate?.tabManagerDidSwitchTab(self, tab: tab)
        
        return tab
    }
    
    func closeTab(id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        
        let wasActive = (index == activeTabIndex)
        tabs[index].webView.stopLoading()
        tabs.remove(at: index)
        
        if tabs.isEmpty {
            // Always keep at least one tab
            addTab()
            return
        }
        
        if wasActive {
            activeTabIndex = min(index, tabs.count - 1)
            if let tab = activeTab {
                delegate?.tabManagerDidSwitchTab(self, tab: tab)
            }
        } else if index < activeTabIndex {
            activeTabIndex -= 1
        }
        
        delegate?.tabManagerDidUpdateTabs(self)
    }
    
    func switchTab(id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        activeTabIndex = index
        if let tab = activeTab {
            delegate?.tabManagerDidSwitchTab(self, tab: tab)
        }
    }
    
    func moveTab(from: Int, to: Int) {
        guard from < tabs.count, to < tabs.count else { return }
        let tab = tabs.remove(at: from)
        tabs.insert(tab, at: to)
        
        if activeTabIndex == from {
            activeTabIndex = to
        } else if from < activeTabIndex && to >= activeTabIndex {
            activeTabIndex -= 1
        } else if from > activeTabIndex && to <= activeTabIndex {
            activeTabIndex += 1
        }
        
        delegate?.tabManagerDidUpdateTabs(self)
    }
    
    func webView(for tab: Tab) -> WKWebView {
        return tab.webView
    }
    
    func newConfiguration() -> WKWebViewConfiguration {
        return configuration_copy
    }
}
