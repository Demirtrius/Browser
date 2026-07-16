import Foundation
import WebKit

class AdBlocker {
    static let shared = AdBlocker()
    
    private var contentRuleList: WKContentRuleList?
    private let ruleListStore = WKContentRuleListStore.default()
    private let rulesIdentifier = "BrowserAdBlockRules"
    
    private init() {
        loadRules()
    }
    
    private func loadRules() {
        guard let rulesURL = Bundle.main.url(forResource: "adblock-rules", withExtension: "json"),
              let rulesJSON = try? String(contentsOf: rulesURL) else {
            print("[AdBlocker] Failed to load rules file")
            return
        }
        
        ruleListStore?.lookUpContentRuleList(forIdentifier: rulesIdentifier) { [weak self] ruleList, error in
            if let ruleList = ruleList, error == nil {
                self?.contentRuleList = ruleList
                return
            }
            
            // Compile new rules
            guard let strongSelf = self else { return }
            strongSelf.ruleListStore?.compileContentRuleList(
                forIdentifier: strongSelf.rulesIdentifier,
                encodedContentRuleList: rulesJSON
            ) { [weak self] ruleList, error in
                if let error = error {
                    print("[AdBlocker] Failed to compile rules: \(error.localizedDescription)")
                    return
                }
                self?.contentRuleList = ruleList
                print("[AdBlocker] Rules compiled successfully")
            }
        }
    }
    
    func apply(to configuration: WKWebViewConfiguration) {
        guard BrowserSettings.shared.adBlockEnabled,
              let ruleList = contentRuleList else { return }
        configuration.userContentController.add(ruleList)
    }
    
    func enable() {
        BrowserSettings.shared.adBlockEnabled = true
    }
    
    func disable() {
        BrowserSettings.shared.adBlockEnabled = false
    }
    
    func reloadRules() {
        ruleListStore?.removeContentRuleList(forIdentifier: rulesIdentifier) { [weak self] (error: Error?) in
            self?.loadRules()
        }
    }
}
