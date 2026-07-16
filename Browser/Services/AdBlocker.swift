import Foundation
import WebKit

class AdBlocker {
    static let shared = AdBlocker()
    
    private var contentRuleList: WKContentRuleList?
    private let ruleListStore = WKContentRuleListStore.default()
    private let rulesIdentifier = "BrowserAdBlockRules"
    
    private init() {
        // Look up cached rules synchronously if possible
        ruleListStore?.lookUpContentRuleList(forIdentifier: rulesIdentifier) { [weak self] ruleList, error in
            if let ruleList = ruleList, error == nil {
                self?.contentRuleList = ruleList
            }
        }
    }
    
    func apply(to configuration: WKWebViewConfiguration) {
        guard BrowserSettings.shared.adBlockEnabled,
              let ruleList = contentRuleList else { return }
        configuration.userContentController.add(ruleList)
    }
}
