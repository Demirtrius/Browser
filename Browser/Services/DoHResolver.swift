import Foundation

class DoHResolver {
    static let shared = DoHResolver()
    
    private var cache: [String: CacheEntry] = [:]
    private let cacheLock = NSLock()
    private let cacheTTL: TimeInterval = 300 // 5 minutes
    
    private struct CacheEntry {
        static let ttl: TimeInterval = 300
        let ip: String
        let timestamp: Date
        
        var isExpired: Bool {
            return Date().timeIntervalSince(timestamp) > CacheEntry.ttl
        }
    }
    
    private init() {}
    
    func resolve(hostname: String, completion: @escaping (String?) -> Void) {
        // Check cache first
        cacheLock.lock()
        if let entry = cache[hostname], !entry.isExpired {
            cacheLock.unlock()
            completion(entry.ip)
            return
        }
        cacheLock.unlock()
        
        guard BrowserSettings.shared.dohEnabled else {
            completion(nil)
            return
        }
        
        let endpoint = BrowserSettings.shared.dohProvider.endpoint
        let queryURL = "\(endpoint)?name=\(hostname)&type=A"
        
        guard let url = URL(string: queryURL) else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/dns-json", forHTTPHeaderField: "Accept")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let data = data, error == nil else {
                completion(nil)
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let answers = json["Answer"] as? [[String: Any]] {
                    
                    // Find first A record (type 1)
                    for answer in answers {
                        if let type = answer["type"] as? Int, type == 1,
                           let ip = answer["data"] as? String {
                            
                            // Cache the result
                            self?.cacheLock.lock()
                            self?.cache[hostname] = CacheEntry(ip: ip, timestamp: Date())
                            self?.cacheLock.unlock()
                            
                            completion(ip)
                            return
                        }
                    }
                }
            } catch {
                print("[DoH] Failed to parse response: \(error)")
            }
            
            completion(nil)
        }.resume()
    }
    
    func createRequest(for originalURL: URL) -> URLRequest? {
        guard let hostname = originalURL.host else { return nil }
        
        // Synchronous resolve using semaphore (with timeout)
        var resolvedIP: String?
        let semaphore = DispatchSemaphore(value: 0)
        
        resolve(hostname: hostname) { ip in
            resolvedIP = ip
            semaphore.signal()
        }
        
        let result = semaphore.wait(timeout: .now() + 2.0) // 2 second timeout
        
        guard result == .success, let ip = resolvedIP else {
            // Fallback to original URL
            return URLRequest(url: originalURL)
        }
        
        // Create new URL with IP instead of hostname
        var components = URLComponents(url: originalURL, resolvingAgainstBaseURL: false)
        components?.host = ip
        
        guard let newURL = components?.url else {
            return URLRequest(url: originalURL)
        }
        
        var request = URLRequest(url: newURL)
        request.setValue(hostname, forHTTPHeaderField: "Host")
        
        return request
    }
    
    func clearCache() {
        cacheLock.lock()
        cache.removeAll()
        cacheLock.unlock()
    }
}
