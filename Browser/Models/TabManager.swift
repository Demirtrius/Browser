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
        
        // Prevent iOS auto-zoom on input focus while keeping manual pinch-zoom
        let zoomJS = """
        (function(){
          var s=document.createElement('style');
          s.textContent='input,select,textarea{font-size:16px !important;}';
          document.documentElement.appendChild(s);
          var v=document.querySelector('meta[name=viewport]');
          if(v){var c=v.getAttribute('content')||'';
            c=c.replace(/user-scalable\\s*=\\s*(no|0)/gi,'user-scalable=yes');
            c=c.replace(/maximum-scale\\s*=\\s*[0-9.]+/gi,'maximum-scale=5');
            v.setAttribute('content',c);}
        })();
        """
        let script = WKUserScript(source: zoomJS, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        config.userContentController.addUserScript(script)
        
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
        return tab
    }
    
    // Returns the removed tab and its former index (for undo). Does NOT auto-create.
    @discardableResult
    func closeTab(id: UUID) -> (tab: Tab, index: Int)? {
        guard let index = tabs.firstIndex(where: { t in t.id == id }) else { return nil }
        let removed = tabs.remove(at: index)
        
        if activeTabId == id {
            if tabs.isEmpty {
                activeTabId = nil
            } else {
                let newIndex = min(index, tabs.count - 1)
                activeTabId = tabs[newIndex].id
            }
        }
        return (removed, index)
    }
    
    func insertTab(_ tab: Tab, at index: Int) {
        let i = min(max(0, index), tabs.count)
        tabs.insert(tab, at: i)
        activeTabId = tab.id
    }
    
    func switchToTab(id: UUID) {
        guard tabs.contains(where: { t in t.id == id }) else { return }
        activeTabId = id
    }
}
