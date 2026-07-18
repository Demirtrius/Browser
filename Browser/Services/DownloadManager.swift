import Foundation
import UIKit

struct DownloadItem {
    let id = UUID()
    var filename: String
    var totalBytes: Int64
    var bytesReceived: Int64 = 0
    var state: State = .downloading
    var localURL: URL?
    
    enum State { case downloading, completed, failed }
    
    var progress: Double {
        totalBytes > 0 ? Double(bytesReceived) / Double(totalBytes) : 0
    }
    
    var progressText: String {
        let received = formatBytes(bytesReceived)
        let total = formatBytes(totalBytes)
        return "\(received) / \(total)"
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        if bytes >= 1_073_741_824 { return String(format: "%.1f GB", Double(bytes) / 1_073_741_824) }
        if bytes >= 1_048_576 { return String(format: "%.1f MB", Double(bytes) / 1_048_576) }
        if bytes >= 1024 { return String(format: "%.1f KB", Double(bytes) / 1024) }
        return "\(bytes) B"
    }
}

class DownloadManager: NSObject, URLSessionDownloadDelegate {
    static let shared = DownloadManager()
    private override init() { super.init() }
    
    private var session: URLSession!
    private var activeDownloads: [UUID: (task: URLSessionDownloadTask, item: DownloadItem)] = [:]
    var onProgress: (([DownloadItem]) -> Void)?
    var onCompleted: ((DownloadItem, URL) -> Void)?
    
    var activeItems: [DownloadItem] {
        activeDownloads.values.map { .item }.sorted { .filename < .filename }
    }
    
    var totalProgress: Double {
        let items = activeItems
        guard !items.isEmpty else { return 0 }
        return items.reduce(0) {  + .progress } / Double(items.count)
    }
    
    var activeCount: Int { activeDownloads.count }
    
    func setup() {
        let config = URLSessionConfiguration.default
        session = URLSession(configuration: config, delegate: self, delegateQueue: .main)
    }
    
    func startDownload(url: URL, suggestedFilename: String? = nil) {
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        
        let task = session.downloadTask(with: request)
        let filename = suggestedFilename ?? url.lastPathComponent ?? "download"
        let item = DownloadItem(filename: filename, totalBytes: 0)
        
        activeDownloads[item.id] = (task, item)
        task.resume()
        notifyProgress()
    }
    
    func cancelDownload(id: UUID) {
        if let entry = activeDownloads.removeValue(forKey: id) {
            entry.task.cancel()
            notifyProgress()
        }
    }
    
    private func notifyProgress() {
        onProgress?(activeItems)
    }
    
    // MARK: - URLSessionDownloadDelegate
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard let entry = activeDownloads.values.first(where: { .task.taskIdentifier == downloadTask.taskIdentifier }) else { return }
        var item = entry.item
        item.bytesReceived = totalBytesWritten
        item.totalBytes = totalBytesExpectedToWrite
        // Update in dictionary
        if let key = activeDownloads.first(where: { .value.task.taskIdentifier == downloadTask.taskIdentifier })?.key {
            activeDownloads[key] = (entry.task, item)
        }
        notifyProgress()
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        guard let entry = activeDownloads.values.first(where: { .task.taskIdentifier == downloadTask.taskIdentifier }) else { return }
        var item = entry.item
        item.state = .completed
        
        // Move to Documents
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dest = docs.appendingPathComponent(item.filename)
        try? FileManager.default.moveItem(at: location, to: dest)
        item.localURL = dest
        
        if let key = activeDownloads.first(where: { .value.task.taskIdentifier == downloadTask.taskIdentifier })?.key {
            activeDownloads.removeValue(forKey: key)
        }
        
        onCompleted?(item, dest)
        notifyProgress()
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            guard let entry = activeDownloads.values.first(where: { .task.taskIdentifier == task.taskIdentifier }) else { return }
            var item = entry.item
            item.state = .failed
            if let key = activeDownloads.first(where: { .value.task.taskIdentifier == task.taskIdentifier })?.key {
                activeDownloads.removeValue(forKey: key)
            }
            print("Download failed: \(error.localizedDescription)")
            notifyProgress()
        }
    }
    
    // MARK: - Helpers
    static func isDownloadable(url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        let downloadable = ["pdf","jpg","jpeg","png","gif","bmp","webp","svg",
            "mp4","mov","avi","mkv","webm","m4v","mp3","wav","aac","flac","ogg","m4a",
            "zip","rar","7z","tar","gz","ipa","apk","dmg","pkg",
            "doc","docx","xls","xlsx","ppt","pptx","txt","csv",
            "exe","msi","deb","apk"]
        return downloadable.contains(ext)
    }
    
    static func iconFor(filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "mp3","wav","aac","flac","ogg","m4a": return "music.note"
        case "mp4","mov","avi","mkv","webm","m4v": return "film"
        case "jpg","jpeg","png","gif","bmp","webp","svg": return "photo"
        case "pdf": return "doc.richtext"
        case "zip","rar","7z","tar","gz": return "archivebox"
        case "ipa","apk","exe","msi","deb","pkg": return "app"
        case "doc","docx": return "doc.text"
        case "xls","xlsx","csv": return "tablecells"
        case "ppt","pptx": return "presentation"
        default: return "doc"
        }
    }
}
