import Foundation
import WebKit

class CookieManager {
    static let shared = CookieManager()
    
    private let defaults = UserDefaults.standard
    private let cookiesKey = "savedCookies"
    
    private init() {}
    
    func saveCookies() {
        guard let cookies = HTTPCookieStorage.shared.cookies, !cookies.isEmpty else { return }
        let dicts = cookies.compactMap { $0.properties }
        let serializable = dicts.map { dict -> [String: Any] in
            var result: [String: Any] = [:]
            for (key, value) in dict {
                result[key.rawValue] = value
            }
            return result
        }
        if let data = try? JSONSerialization.data(withJSONObject: serializable) {
            defaults.set(data, forKey: cookiesKey)
        }
    }
    
    func restoreCookies() {
        guard let data = defaults.data(forKey: cookiesKey),
              let dicts = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return }
        
        for dict in dicts {
            var props: [HTTPCookiePropertyKey: Any] = [:]
            for (k, v) in dict { props[HTTPCookiePropertyKey(k)] = v }
            if let cookie = HTTPCookie(properties: props) {
                HTTPCookieStorage.shared.setCookie(cookie)
            }
        }
    }
    
    func clearAllData(completion: (() -> Void)? = nil) {
        let dataStore = WKWebsiteDataStore.default()
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        dataStore.removeData(ofTypes: types, modifiedSince: Date(timeIntervalSince1970: 0)) {
            if let cookies = HTTPCookieStorage.shared.cookies {
                for cookie in cookies { HTTPCookieStorage.shared.deleteCookie(cookie) }
            }
            self.defaults.removeObject(forKey: self.cookiesKey)
            DispatchQueue.main.async { completion?() }
        }
    }
}
