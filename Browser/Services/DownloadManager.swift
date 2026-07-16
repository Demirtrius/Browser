import Foundation
import UIKit

protocol DownloadManagerDelegate: AnyObject {
    func downloadManager(_ manager: DownloadManager, didStartDownload fileName: String)
    func downloadManager(_ manager: DownloadManager, didUpdateProgress progress: Float, fileName: String)
    func downloadManager(_ manager: DownloadManager, didFinishDownload fileName: String, savedTo: URL)
    func downloadManager(_ manager: DownloadManager, didFailDownload fileName: String, error: Error)
}

class DownloadManager: NSObject {
    static let shared = DownloadManager()
    
    weak var delegate: DownloadManagerDelegate?
    
    private var activeDownloads: [URLSessionDownloadTask: String] = [:]
    private var downloadProgress: [String: Float] = [:]
    
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300
        config.timeoutIntervalForResource = 3600
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()
    
    private override init() {
        super.init()
    }
    
    func startDownload(from url: URL, suggestedFilename: String) {
        let task = session.downloadTask(with: URLRequest(url: url))
        activeDownloads[task] = suggestedFilename
        downloadProgress[suggestedFilename] = 0.0
        task.resume()
        
        DispatchQueue.main.async {
            self.delegate?.downloadManager(self, didStartDownload: suggestedFilename)
        }
    }
    
    func isDownloadableURL(_ url: URL, response: URLResponse) -> Bool {
        // Check Content-Disposition header for attachment
        if let httpResponse = response as? HTTPURLResponse,
           let contentDisposition = httpResponse.allHeaderFields["Content-Disposition"] as? String {
            if contentDisposition.lowercased().contains("attachment") {
                return true
            }
        }
        
        // Check MIME type for actual downloadable files only (NOT images/text/html)
        if let mimeType = response.mimeType?.lowercased() {
            // Never intercept main page content or images (browser should display them)
            if mimeType.hasPrefix("text/") || mimeType.hasPrefix("image/") || 
               mimeType.hasPrefix("video/") || mimeType.hasPrefix("audio/") ||
               mimeType.hasPrefix("application/json") || mimeType.hasPrefix("application/xml") ||
               mimeType.hasPrefix("multipart/") {
                return false
            }
            
            let downloadableTypes = [
                "application/pdf",
                "application/zip",
                "application/x-rar-compressed",
                "application/x-7z-compressed",
                "application/x-tar",
                "application/gzip",
                "application/msword",
                "application/vnd.openxmlformats",
                "application/vnd.android.package-archive",
                "application/octet-stream"
            ]
            
            for type in downloadableTypes {
                if mimeType.hasPrefix(type) {
                    return true
                }
            }
        }
        
        // Check file extension for actual downloadable files
        let pathExtension = url.pathExtension.lowercased()
        let downloadableExtensions = [
            "pdf", "zip", "rar", "7z", "tar", "gz",
            "doc", "docx", "xls", "xlsx", "ppt", "pptx",
            "mp3", "mp4", "avi", "mkv", "mov", "flac",
            "apk", "exe", "dmg", "iso"
        ]
        
        return downloadableExtensions.contains(pathExtension)
    }
    
    func suggestedFilename(from response: URLResponse, url: URL) -> String {
        // Try Content-Disposition header
        if let httpResponse = response as? HTTPURLResponse,
           let contentDisposition = httpResponse.allHeaderFields["Content-Disposition"] as? String {
            let patterns = ["filename=\"", "filename="]
            for pattern in patterns {
                if let range = contentDisposition.range(of: pattern) {
                    var filename = String(contentDisposition[range.upperBound...])
                    if let endRange = filename.range(of: "\"") {
                        filename = String(filename[..<endRange.lowerBound])
                    } else if let endRange = filename.range(of: ";") {
                        filename = String(filename[..<endRange.lowerBound])
                    }
                    filename = filename.trimmingCharacters(in: .whitespaces)
                    if !filename.isEmpty {
                        return filename
                    }
                }
            }
        }
        
        // Fallback to URL path
        return url.lastPathComponent.isEmpty ? "download" : url.lastPathComponent
    }
    
    private func saveDirectory() -> URL {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let folderName = BrowserSettings.shared.downloadFolder
        let downloadDir = documentsDir.appendingPathComponent(folderName)
        
        if !FileManager.default.fileExists(atPath: downloadDir.path) {
            try? FileManager.default.createDirectory(at: downloadDir, withIntermediateDirectories: true)
        }
        
        return downloadDir
    }
}

extension DownloadManager: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let fileName = activeDownloads[downloadTask] else { return }
        
        let progress: Float
        if totalBytesExpectedToWrite > 0 {
            progress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
        } else {
            progress = 0
        }
        
        downloadProgress[fileName] = progress
        
        DispatchQueue.main.async {
            self.delegate?.downloadManager(self, didUpdateProgress: progress, fileName: fileName)
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let fileName = activeDownloads[downloadTask] else { return }
        
        let destinationURL = saveDirectory().appendingPathComponent(fileName)
        
        // Remove existing file if any
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try? FileManager.default.removeItem(at: destinationURL)
        }
        
        do {
            try FileManager.default.moveItem(at: location, to: destinationURL)
            
            DispatchQueue.main.async {
                self.delegate?.downloadManager(self, didFinishDownload: fileName, savedTo: destinationURL)
            }
        } catch {
            DispatchQueue.main.async {
                self.delegate?.downloadManager(self, didFailDownload: fileName, error: error)
            }
        }
        
        activeDownloads.removeValue(forKey: downloadTask)
        downloadProgress.removeValue(forKey: fileName)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error, let downloadTask = task as? URLSessionDownloadTask,
           let fileName = activeDownloads[downloadTask] {
            
            DispatchQueue.main.async {
                self.delegate?.downloadManager(self, didFailDownload: fileName, error: error)
            }
            
            activeDownloads.removeValue(forKey: downloadTask)
            downloadProgress.removeValue(forKey: fileName)
        }
    }
}
