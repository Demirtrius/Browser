import Foundation

class BrowserSettings {
    static let shared = BrowserSettings()
    
    private let defaults = UserDefaults.standard
    
    // MARK: - Keys
    private enum Keys {
        static let homepage = "homepage"
        static let searchEngine = "searchEngine"
        static let adBlockEnabled = "adBlockEnabled"
        static let dohEnabled = "dohEnabled"
        static let dohProvider = "dohProvider"
        static let downloadFolder = "downloadFolder"
        static let cookiesData = "cookiesData"
    }
    
    // MARK: - Defaults
    private enum Defaults {
        static let homepage = "https://www.google.com"
        static let searchEngine = "google"
        static let adBlockEnabled = true
        static let dohEnabled = true
        static let dohProvider = "cloudflare"
        static let downloadFolder = "Downloads"
    }
    
    private init() {}
    
    // MARK: - Homepage
    var homepage: String {
        get { defaults.string(forKey: Keys.homepage) ?? Defaults.homepage }
        set { defaults.set(newValue, forKey: Keys.homepage) }
    }
    
    // MARK: - Search Engine
    enum SearchEngine: String, CaseIterable {
        case google = "google"
        case bing = "bing"
        case duckduckgo = "duckduckgo"
        
        var displayName: String {
            switch self {
            case .google: return "Google"
            case .bing: return "Bing"
            case .duckduckgo: return "DuckDuckGo"
            }
        }
        
        var searchURL: String {
            switch self {
            case .google: return "https://www.google.com/search?q="
            case .bing: return "https://www.bing.com/search?q="
            case .duckduckgo: return "https://duckduckgo.com/?q="
            }
        }
    }
    
    var searchEngine: SearchEngine {
        get {
            let raw = defaults.string(forKey: Keys.searchEngine) ?? Defaults.searchEngine
            return SearchEngine(rawValue: raw) ?? .google
        }
        set { defaults.set(newValue.rawValue, forKey: Keys.searchEngine) }
    }
    
    func searchURL(for query: String) -> URL? {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return URL(string: searchEngine.searchURL + encoded)
    }
    
    // MARK: - Ad Blocker
    var adBlockEnabled: Bool {
        get { defaults.bool(forKey: Keys.adBlockEnabled) }
        set { defaults.set(newValue, forKey: Keys.adBlockEnabled) }
    }
    
    // MARK: - DNS over HTTPS
    var dohEnabled: Bool {
        get { defaults.bool(forKey: Keys.dohEnabled) }
        set { defaults.set(newValue, forKey: Keys.dohEnabled) }
    }
    
    enum DoHProvider: String, CaseIterable {
        case cloudflare = "cloudflare"
        case google = "google"
        
        var displayName: String {
            switch self {
            case .cloudflare: return "Cloudflare"
            case .google: return "Google"
            }
        }
        
        var endpoint: String {
            switch self {
            case .cloudflare: return "https://cloudflare-dns.com/dns-query"
            case .google: return "https://dns.google/dns-query"
            }
        }
    }
    
    var dohProvider: DoHProvider {
        get {
            let raw = defaults.string(forKey: Keys.dohProvider) ?? Defaults.dohProvider
            return DoHProvider(rawValue: raw) ?? .cloudflare
        }
        set { defaults.set(newValue.rawValue, forKey: Keys.dohProvider) }
    }
    
    // MARK: - Download Folder
    var downloadFolder: String {
        get { defaults.string(forKey: Keys.downloadFolder) ?? Defaults.downloadFolder }
        set { defaults.set(newValue, forKey: Keys.downloadFolder) }
    }
    
    // MARK: - Cookies Persistence
    func saveCookiesData(_ data: Data) {
        defaults.set(data, forKey: Keys.cookiesData)
    }
    
    func loadCookiesData() -> Data? {
        return defaults.data(forKey: Keys.cookiesData)
    }
    
    // MARK: - Clear Data
    func clearAllData() {
        let domain = Bundle.main.bundleIdentifier ?? ""
        defaults.removePersistentDomain(forName: domain)
        defaults.synchronize()
    }
}
