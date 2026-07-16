import Foundation
import WebKit

class CookieManager {
    static let shared = CookieManager()
    
    private let defaults = UserDefaults.standard
    private let cookiesKey = "savedCookies"
    
    private init() {}
    
    // MARK: - Save Cookies
    func saveCookies() {
        let cookies = HTTPCookieStorage.shared.cookies ?? []
        let cookieDictionaries = cookies.map { $0.properties }
        
        do {
            let data = try JSONSerialization.data(withJSONObject: cookieDictionaries)
            defaults.set(data, forKey: cookiesKey)
        } catch {
            print("[CookieManager] Failed to save cookies: \(error)")
        }
    }
    
    // MARK: - Restore Cookies
    func restoreCookies() {
        guard let data = defaults.data(forKey: cookiesKey),
              let cookieDictionaries = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return
        }
        
        let cookies = cookieDictionaries.compactMap { properties -> HTTPCookie? in
            return HTTPCookie(properties: properties)
        }
        
        let storage = HTTPCookieStorage.shared
        for cookie in cookies {
            storage.setCookie(cookie)
        }
        
        print("[CookieManager] Restored \(cookies.count) cookies")
    }
    
    // MARK: - Clear History (keep cookies)
    func clearHistory() {
        let dataStore = WKWebsiteDataStore.default()
        let dataTypes: Set<String> = [
            WKWebsiteDataTypeDiskCache,
            WKWebsiteDataTypeOfflineWebApplicationCache,
            WKWebsiteDataTypeMemoryCache,
            WKWebsiteDataTypeLocalStorage,
            WKWebsiteDataTypeWebSQLDatabases,
            WKWebsiteDataTypeIndexedDBDatabases,
            WKWebsiteDataTypeFetchCache,
            WKWebsiteDataTypeServiceWorkerRegistrations
        ]
        
        let date = Date(timeIntervalSince1970: 0)
        dataStore.removeData(ofTypes: dataTypes, modifiedSince: date) {
            print("[CookieManager] History cleared")
        }
    }
    
    // MARK: - Clear All Data (including cookies)
    func clearAllData(completion: (() -> Void)? = nil) {
        let dataStore = WKWebsiteDataStore.default()
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        
        let date = Date(timeIntervalSince1970: 0)
        dataStore.removeData(ofTypes: dataTypes, modifiedSince: date) {
            // Clear HTTP cookies
            if let cookies = HTTPCookieStorage.shared.cookies {
                for cookie in cookies {
                    HTTPCookieStorage.shared.deleteCookie(cookie)
                }
            }
            
            // Clear saved cookies from UserDefaults
            self.defaults.removeObject(forKey: self.cookiesKey)
            
            print("[CookieManager] All data cleared")
            completion?()
        }
    }
    
    // MARK: - Clear Back/Forward List for a WebView
    func clearBackForwardList(for webView: WKWebView) {
        // Navigate to current page to clear back/forward list
        if let currentURL = webView.url {
            webView.load(URLRequest(url: currentURL))
        }
    }
}
