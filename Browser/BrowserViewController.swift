import UIKit
import WebKit

class BrowserViewController: UIViewController, UITextFieldDelegate, WKNavigationDelegate, WKUIDelegate, TabOverviewDelegate, UITableViewDataSource, UITableViewDelegate, DownloadsPanelDelegate {
    
    private let tabManager = TabManager()
    private var textField: UITextField!
    private var spinner: UIActivityIndicatorView!
    private var tabButton: UIButton!
    private var progressRing: CircularProgressView!
    private var downloadsPanel: DownloadsPanelView!
    private var tabOverview: TabOverviewView!
    private var showingOverview = false
    
    // Search suggestions
    private var suggestionsTable: UITableView!
    private var suggestions: [String] = []
    private var suggestionTask: URLSessionDataTask?
    private var debounceTimer: Timer?
    private var suggestionsHeight: NSLayoutConstraint!
    
    // Undo close
    private var lastClosedTab: Tab?
    private var lastClosedIndex: Int = 0
    private var autoCreatedOnClose = false
    private var snackbar: UIView!
    private var snackbarLabel: UILabel!
    private var snackbarTimer: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .dark
        view.backgroundColor = UIColor(hex: 0x1C1C1E)
        
        setupTopBar()
        setupSuggestionsView()
        setupTabOverview()
        setupDownloadsPanel()
        setupProgressRing()
        setupLongPress()
        DownloadManager.shared.setup()
        DownloadManager.shared.onProgress = { [weak self] items in
            self?.updateDownloadProgress(items)
        }
        setupSnackbar()
        
        // Create first tab
        let tab = tabManager.addTab()
        setupWebView(tab)
        view.insertSubview(tab.webView, belowSubview: textField)
        pinWebView(tab.webView)
        tab.webView.load(URLRequest(url: URL(string: "https://www.google.com")!))
        
        // Edge swipes
        let back = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(swipeBack))
        back.edges = .left
        view.addGestureRecognizer(back)
        let fwd = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(swipeFwd))
        fwd.edges = .right
        view.addGestureRecognizer(fwd)
    }
    
    private func setupTopBar() {
        textField = UITextField()
        textField.font = .systemFont(ofSize: 14)
        textField.textColor = .white
        textField.backgroundColor = UIColor(hex: 0x3A3A3C)
        textField.borderStyle = .none
        textField.layer.cornerRadius = 8
        textField.keyboardAppearance = .dark
        textField.returnKeyType = .go
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.clearButtonMode = .never
        textField.delegate = self
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        view.addSubview(textField)
        
        spinner = UIActivityIndicatorView(style: .medium)
        spinner.color = UIColor(hex: 0x6CB4FF)
        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        
        tabButton = UIButton(type: .system)
        tabButton.backgroundColor = UIColor(hex: 0x3A3A3C)
        tabButton.layer.cornerRadius = 6
        tabButton.setTitleColor(.white, for: .normal)
        tabButton.titleLabel?.font = .systemFont(ofSize: 12, weight: .bold)
        tabButton.setTitle("1", for: .normal)
        tabButton.translatesAutoresizingMaskIntoConstraints = false
        tabButton.addTarget(self, action: #selector(showTabOverview), for: .touchUpInside)
        tabButton.addSubview(spinner)
        view.addSubview(tabButton)
        
        NSLayoutConstraint.activate([
            textField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            textField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            textField.trailingAnchor.constraint(equalTo: tabButton.leadingAnchor, constant: -8),
            textField.heightAnchor.constraint(equalToConstant: 36),
            tabButton.centerYAnchor.constraint(equalTo: textField.centerYAnchor),
            tabButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            tabButton.widthAnchor.constraint(equalToConstant: 32),
            tabButton.heightAnchor.constraint(equalToConstant: 28),
            spinner.centerXAnchor.constraint(equalTo: tabButton.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: tabButton.centerYAnchor),
        ])
    }
    
    // MARK: - Search Suggestions
    private func setupSuggestionsView() {
        suggestionsTable = UITableView()
        suggestionsTable.backgroundColor = UIColor(hex: 0x2C2C2E)
        suggestionsTable.delegate = self
        suggestionsTable.dataSource = self
        suggestionsTable.keyboardDismissMode = .none
        suggestionsTable.isHidden = true
        suggestionsTable.translatesAutoresizingMaskIntoConstraints = false
        suggestionsTable.register(UITableViewCell.self, forCellReuseIdentifier: "sug")
        suggestionsTable.separatorColor = UIColor(hex: 0x3A3A3C)
        suggestionsTable.rowHeight = 40
        view.addSubview(suggestionsTable)
        view.bringSubviewToFront(suggestionsTable)
        
        NSLayoutConstraint.activate([
            suggestionsTable.topAnchor.constraint(equalTo: textField.bottomAnchor, constant: 2),
            suggestionsTable.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            suggestionsTable.trailingAnchor.constraint(equalTo: tabButton.trailingAnchor),
        ])
        suggestionsHeight = suggestionsTable.heightAnchor.constraint(equalToConstant: 200)
        suggestionsHeight.isActive = true
    }
    
    private func fetchSuggestions(for text: String) {
        suggestionTask?.cancel()
        guard !text.isEmpty else {
            hideSuggestions()
            return
        }
        
        let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text
        let urlString = "https://suggestqueries.google.com/complete/search?client=firefox&hl=tr&q=" + encoded
        
        guard let url = URL(string: urlString) else { return }
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        
        suggestionTask = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self, let data = data else { return }
            
            var items: [String] = []
            // client=firefox returns ISO-8859-9 sometimes; decode robustly
            let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? ""
            if let jsonData = text.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: jsonData) as? [Any],
               json.count >= 2,
               let suggestions = json[1] as? [String] {
                items = Array(suggestions.prefix(4))
            }
            
            DispatchQueue.main.async {
                self.suggestions = items
                self.suggestionsTable.reloadData()
                self.suggestionsTable.isHidden = items.isEmpty
                // Dynamic height: 40px per row, max 200px, no empty space
                let h = CGFloat(min(items.count * 40, 200))
                self.suggestionsHeight.constant = h
                if !items.isEmpty {
                    self.view.bringSubviewToFront(self.suggestionsTable)
                }
            }
        }
        suggestionTask?.resume()
    }
    
    private func hideSuggestions() {
        suggestionsTable.isHidden = true
        suggestions = []
    }
    
    // MARK: - UITableViewDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return suggestions.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "sug", for: indexPath)
        cell.textLabel?.text = suggestions[indexPath.row]
        cell.textLabel?.textColor = .white
        cell.textLabel?.font = .systemFont(ofSize: 14)
        cell.backgroundColor = UIColor(hex: 0x2C2C2E)
        
        // Search icon
        let icon = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        icon.tintColor = UIColor(hex: 0x98989D)
        icon.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
        cell.accessoryView = icon
        
        return cell
    }
    
    // MARK: - UITableViewDelegate
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        let query = suggestions[indexPath.row]
        textField.text = query
        hideSuggestions()
        textField.resignFirstResponder()
        let url = parseURL(query)
        tabManager.activeTab?.webView.load(URLRequest(url: url))
    }
    
    private func setupLongPress() {
        let lp = UILongPressGestureRecognizer(target: self, action: #selector(tabButtonLongPressed(_:)))
        lp.minimumPressDuration = 0.5
        tabButton.addGestureRecognizer(lp)
    }
    
    @objc private func tabButtonLongPressed(_ g: UILongPressGestureRecognizer) {
        guard g.state == .began else { return }
        showDownloadsPanel()
    }
    
    // MARK: - Download Progress Ring
    private func setupProgressRing() {
        progressRing = CircularProgressView()
        progressRing.translatesAutoresizingMaskIntoConstraints = false
        tabButton.addSubview(progressRing)
        NSLayoutConstraint.activate([
            progressRing.topAnchor.constraint(equalTo: tabButton.topAnchor, constant: -4),
            progressRing.leadingAnchor.constraint(equalTo: tabButton.leadingAnchor, constant: -4),
            progressRing.trailingAnchor.constraint(equalTo: tabButton.trailingAnchor, constant: 4),
            progressRing.bottomAnchor.constraint(equalTo: tabButton.bottomAnchor, constant: 4),
        ])
    }
    
    private func updateDownloadProgress(_ items: [DownloadItem]) {
        let count = items.count
        progressRing.isHidden = count == 0  // Hide ring when no downloads
        if count > 0 {
            progressRing.progress = DownloadManager.shared.totalProgress
            tabButton.setTitle(String(count), for: .normal)
        } else {
            progressRing.progress = 0
            updateTabButton()
        }
        
        // Also dismiss downloads panel if no active downloads
        if count == 0 && !downloadsPanel.isHidden {
            dismissDownloadsPanel()
        }
    }
    
    @objc private func dismissDownloadsPanel() {
        hideDownloadsPanel()
    }
    
    // MARK: - Downloads Panel
    private func setupDownloadsPanel() {
        downloadsPanel = DownloadsPanelView()
        downloadsPanel.delegate = self
        downloadsPanel.isHidden = true
        downloadsPanel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(downloadsPanel)
        NSLayoutConstraint.activate([
            downloadsPanel.topAnchor.constraint(equalTo: view.topAnchor),
            downloadsPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            downloadsPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            downloadsPanel.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        
        // Add swipe gesture to dismiss downloads panel
        let swipeDismiss = UISwipeGestureRecognizer(target: self, action: #selector(dismissDownloadsPanel))
        swipeDismiss.direction = .down
        downloadsPanel.addGestureRecognizer(swipeDismiss)
    }
    
    private func showDownloadsPanel() {
        downloadsPanel.isHidden = false
        downloadsPanel.alpha = 0
        downloadsPanel.updateDownloads(DownloadManager.shared.activeItems)
        UIView.animate(withDuration: 0.2) { self.downloadsPanel.alpha = 1 }
    }
    
    private func hideDownloadsPanel() {
        UIView.animate(withDuration: 0.2, animations: { self.downloadsPanel.alpha = 0 }) { _ in
            self.downloadsPanel.isHidden = true
        }
    }
    
    // MARK: - DownloadsPanelDelegate
    func downloadsPanelDidCancel(id: UUID) {
        DownloadManager.shared.cancelDownload(id: id)
        downloadsPanel.updateDownloads(DownloadManager.shared.activeItems)
    }
    
    func downloadsPanelDidDismiss() {
        hideDownloadsPanel()
    }
    private func setupTabOverview() {
        tabOverview = TabOverviewView()
        tabOverview.delegate = self
        tabOverview.isHidden = true
        tabOverview.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tabOverview)
        NSLayoutConstraint.activate([
            tabOverview.topAnchor.constraint(equalTo: view.topAnchor),
            tabOverview.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabOverview.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabOverview.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
    
    // MARK: - Undo Snackbar
    private func setupSnackbar() {
        snackbar = UIView()
        snackbar.backgroundColor = UIColor(hex: 0x2C2C2E)
        snackbar.layer.cornerRadius = 10
        snackbar.layer.shadowColor = UIColor.black.cgColor
        snackbar.layer.shadowOpacity = 0.5
        snackbar.layer.shadowOffset = CGSize(width: 0, height: 2)
        snackbar.layer.shadowRadius = 6
        snackbar.alpha = 0
        snackbar.isHidden = true
        snackbar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(snackbar)
        
        snackbarLabel = UILabel()
        snackbarLabel.font = .systemFont(ofSize: 14)
        snackbarLabel.textColor = .white
        snackbarLabel.lineBreakMode = .byTruncatingTail
        snackbarLabel.translatesAutoresizingMaskIntoConstraints = false
        snackbar.addSubview(snackbarLabel)
        
        let undoBtn = UIButton(type: .system)
        undoBtn.setTitle("GERİ AL", for: .normal)
        undoBtn.setTitleColor(UIColor(hex: 0x6CB4FF), for: .normal)
        undoBtn.titleLabel?.font = .systemFont(ofSize: 14, weight: .bold)
        undoBtn.translatesAutoresizingMaskIntoConstraints = false
        undoBtn.addTarget(self, action: #selector(undoClose), for: .touchUpInside)
        snackbar.addSubview(undoBtn)
        
        NSLayoutConstraint.activate([
            snackbar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            snackbar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            snackbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            snackbar.heightAnchor.constraint(equalToConstant: 50),
            
            snackbarLabel.leadingAnchor.constraint(equalTo: snackbar.leadingAnchor, constant: 16),
            snackbarLabel.centerYAnchor.constraint(equalTo: snackbar.centerYAnchor),
            snackbarLabel.trailingAnchor.constraint(equalTo: undoBtn.leadingAnchor, constant: -12),
            
            undoBtn.trailingAnchor.constraint(equalTo: snackbar.trailingAnchor, constant: -16),
            undoBtn.centerYAnchor.constraint(equalTo: snackbar.centerYAnchor),
            undoBtn.widthAnchor.constraint(equalToConstant: 72),
        ])
    }
    
    private func showUndoSnackbar(title: String) {
        snackbarLabel.text = "Kapatıldı: \(title)"
        snackbar.isHidden = false
        view.bringSubviewToFront(snackbar)
        UIView.animate(withDuration: 0.2) { self.snackbar.alpha = 1 }
        
        snackbarTimer?.invalidate()
        snackbarTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.hideSnackbar()
        }
    }
    
    private func hideSnackbar() {
        snackbarTimer?.invalidate()
        UIView.animate(withDuration: 0.2, animations: { self.snackbar.alpha = 0 }) { _ in
            self.snackbar.isHidden = true
        }
        lastClosedTab = nil
    }
    
    @objc private func undoClose() {
        guard let tab = lastClosedTab else { hideSnackbar(); return }
        // Remove the auto-created replacement tab if one was made
        if autoCreatedOnClose, let auto = tabManager.activeTab {
            _ = tabManager.closeTab(id: auto.id)
            auto.webView.removeFromSuperview()
            autoCreatedOnClose = false
        }
        tabManager.insertTab(tab, at: lastClosedIndex)
        setupWebView(tab)
        lastClosedTab = nil
        switchToActiveTab()
        if showingOverview { refreshOverview() }
        hideSnackbar()
    }
    
    private func pinWebView(_ webView: WKWebView) {
        webView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: textField.bottomAnchor, constant: 8),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
    
    // MARK: - Helper
    private func setupWebView(_ tab: Tab) {
        tab.webView.navigationDelegate = self
        tab.webView.uiDelegate = self
        tab.webView.scrollView.contentInsetAdjustmentBehavior = .never
        let rc = UIRefreshControl()
        rc.tintColor = UIColor(hex: 0x6CB4FF)
        rc.addTarget(self, action: #selector(pullToRefresh(_:)), for: .valueChanged)
        tab.webView.scrollView.refreshControl = rc
    }
    
    @objc private func pullToRefresh(_ sender: UIRefreshControl) {
        tabManager.activeTab?.webView.reload()
    }
    
    // MARK: - Tab Switching
    private func switchToActiveTab() {
        guard let activeTab = tabManager.activeTab else { return }
        
        for tab in tabManager.tabs {
            tab.webView.removeFromSuperview()
        }
        view.insertSubview(activeTab.webView, belowSubview: textField)
        pinWebView(activeTab.webView)
        
        // If tab has no content loaded yet, load Google
        if activeTab.webView.url == nil {
            activeTab.webView.load(URLRequest(url: URL(string: "https://www.google.com")!))
        }
        
        textField.text = activeTab.webView.url?.absoluteString ?? activeTab.url
        if activeTab.webView.isLoading { showSpinner(true) } else { showSpinner(false) }
        updateTabButton()
    }
    
    private func updateTabButton() {
        tabButton.setTitle("\(tabManager.tabCount)", for: .normal)
    }
    
    private func showSpinner(_ show: Bool) {
        if show {
            tabButton.setTitle("", for: .normal)
            spinner.startAnimating()
        } else {
            spinner.stopAnimating()
            updateTabButton()
        }
    }
    
    @objc private func showTabOverview() {
        // Capture snapshot of active tab first, then present
        if let active = tabManager.activeTab, active.webView.superview != nil, active.webView.bounds.width > 0 {
            let config = WKSnapshotConfiguration()
            config.afterScreenUpdates = false
            active.webView.takeSnapshot(with: config) { [weak self] image, _ in
                if let image = image { active.snapshot = image }
                self?.presentOverview()
            }
        } else {
            presentOverview()
        }
    }
    
    private func presentOverview() {
        showingOverview = true
        tabOverview.isHidden = false
        tabOverview.alpha = 0
        refreshOverview()
        UIView.animate(withDuration: 0.2) { self.tabOverview.alpha = 1 }
    }
    
    private func hideOverview() {
        showingOverview = false
        UIView.animate(withDuration: 0.2, animations: { self.tabOverview.alpha = 0 }) { _ in
            self.tabOverview.isHidden = true
        }
    }
    
    private func refreshOverview() {
        let items = tabManager.tabs.map { tab in (id: tab.id, title: tab.title, url: tab.url, snapshot: tab.snapshot) }
        tabOverview.updateTabs(items, activeId: tabManager.activeTabId)
    }
    
    // MARK: - TabOverviewDelegate
    func tabOverviewDidSelectTab(id: UUID) {
        tabManager.switchToTab(id: id)
        switchToActiveTab()
        hideOverview()
    }
    
    func tabOverviewDidCloseTab(id: UUID) {
        guard let closed = tabManager.closeTab(id: id) else { return }
        closed.tab.webView.removeFromSuperview()
        lastClosedTab = closed.tab
        lastClosedIndex = closed.index
        autoCreatedOnClose = false
        
        // Always keep at least one tab
        if tabManager.tabCount == 0 {
            let tab = tabManager.addTab()
            setupWebView(tab)
            tab.webView.load(URLRequest(url: URL(string: "https://www.google.com")!))
            autoCreatedOnClose = true
        }
        
        switchToActiveTab()
        refreshOverview()
        showUndoSnackbar(title: closed.tab.title.isEmpty ? "New Tab" : closed.tab.title)
    }
    
    func tabOverviewDidAddTab() {
        let tab = tabManager.addTab()
        setupWebView(tab)
        tab.webView.load(URLRequest(url: URL(string: "https://www.google.com")!))
        switchToActiveTab()
        hideOverview()
    }
    
    @objc private func textFieldDidChange() {
        guard let text = textField.text else { return }
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            self?.fetchSuggestions(for: text)
        }
    }
    
    func tabOverviewDidDismiss() {
        hideOverview()
    }
    
    // MARK: - Swipe Gestures
    @objc private func swipeBack(_ g: UIScreenEdgePanGestureRecognizer) {
        guard g.state == .ended, let wv = tabManager.activeTab?.webView, wv.canGoBack else { return }
        wv.goBack()
    }
    
    @objc private func swipeFwd(_ g: UIScreenEdgePanGestureRecognizer) {
        guard g.state == .ended, let wv = tabManager.activeTab?.webView, wv.canGoForward else { return }
        wv.goForward()
    }
    
    // MARK: - UITextFieldDelegate
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard let text = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            textField.resignFirstResponder()
            return true
        }
        hideSuggestions()
        let url = parseURL(text)
        tabManager.activeTab?.webView.load(URLRequest(url: url))
        textField.resignFirstResponder()
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        hideSuggestions()
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        DispatchQueue.main.async { textField.selectAll(nil) }
    }
    

    
    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        hideSuggestions()
        return true
    }
    
    // MARK: - URL Parsing
    private func parseURL(_ text: String) -> URL {
        if text.hasPrefix("http://") || text.hasPrefix("https://") {
            if let url = URL(string: text) { return url }
        }
        let ipPattern = #"^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}(:\d+)?$"#
        if text.range(of: ipPattern, options: .regularExpression) != nil {
            return URL(string: "http://" + text) ?? URL(string: "https://www.google.com/search?q=" + text)!
        }
        if text.contains(".") && !text.contains(" ") {
            return URL(string: "https://" + text) ?? URL(string: "https://www.google.com/search?q=" + text)!
        }
        let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text
        return URL(string: "https://www.google.com/search?q=" + encoded)!
    }
    
    // MARK: - Error Page HTML
    private func errorHTML(for url: URL?, error: Error) -> String {
        let domain = url?.host ?? "this page"
        let msg = error.localizedDescription
        return """
        <!DOCTYPE html><html><head><meta name='viewport' content='width=device-width,initial-scale=1'>
        <style>body{background:#1C1C1E;color:#fff;font-family:-apple-system;display:flex;justify-content:center;
        align-items:center;min-height:80vh;text-align:center;padding:20px}
        .c{max-width:400px}h1{font-size:48px;margin-bottom:8px}h2{font-size:18px;font-weight:400;color:#98989D;margin-bottom:24px}
        p{color:#636366;font-size:14px;line-height:1.5;margin-bottom:24px}
        a{color:#6CB4FF;text-decoration:none;font-size:16px;font-weight:500;
        background:#3A3A3C;padding:12px 32px;border-radius:8px;display:inline-block}</style></head>
        <body><div class='c'><h1>:(</h1><h2>This site can't be reached</h2>
        <p><b>\(domain)</b> refused to connect.<br>\(msg)</p>
        <a href='javascript:window.location.reload()'>Retry</a></div></body></html>
        """
    }
    
    // MARK: - WKNavigationDelegate
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = navigationAction.request.url {
            let scheme = url.scheme?.lowercased() ?? ""
            // Exclude about: and blob: schemes
            if scheme != "about" && scheme != "blob" && DownloadManager.isDownloadable(url: url) {
                DownloadManager.shared.startDownload(url: url)
                decisionHandler(.cancel)
                return
            }
        }
        decisionHandler(.allow)
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if let url = navigationResponse.response.url {
            let scheme = url.scheme?.lowercased() ?? ""
            if scheme != "about" && scheme != "blob" && DownloadManager.isDownloadable(url: url) {
                DownloadManager.shared.startDownload(url: url)
                decisionHandler(.cancel)
                return
            }
        }
        // Also check Content-Disposition header
        if let response = navigationResponse.response as? HTTPURLResponse,
           let disposition = response.value(forHTTPHeaderField: "Content-Disposition"),
           disposition.contains("attachment") {
            if let url = navigationResponse.response.url {
                let filename: String?
                if let range = disposition.range(of: "filename=\""),
                   let endRange = disposition[range.upperBound...].range(of: "\"") {
                    filename = String(disposition[range.upperBound..<endRange.lowerBound])
                } else {
                    filename = url.lastPathComponent
                }
                DownloadManager.shared.startDownload(url: url, suggestedFilename: filename)
            }
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.scrollView.refreshControl?.endRefreshing()
        showSpinner(false)
        guard let tab = tabManager.tabs.first(where: { tab in tab.webView == webView }) else { return }
        tab.title = webView.title ?? "Untitled"
        tab.url = webView.url?.absoluteString ?? ""
        if webView == tabManager.activeTab?.webView {
            textField.text = webView.url?.absoluteString
            // Refresh overview if open (so new tab shows loaded page)
            if showingOverview { refreshOverview() }
        }
        
        // Auto-reset zoom to 1.0x and hide vertical scrollbar on Google.com
        if let url = webView.url, let host = url.host?.lowercased(), host.contains("google.com") {
            // Full viewport fit CSS + scrollbar hide + zoom reset
            let css = """
            * { box-sizing: border-box; }
            html, body { margin: 0; padding: 0; width: 100%; height: 100%; }
            html { -webkit-user-select: none; } 
            ::-webkit-scrollbar:vertical { display: none; }
            """
            let jsCode = """
            document.body.style.webkitTextSizeAdjust = '100%';
            document.documentElement.style.webkitTextSizeAdjust = '100%';
            const style = document.createElement('style');
            style.textContent = '\(css)';
            document.head.appendChild(style);
            """
            webView.evaluateJavaScript(jsCode)
            // Force viewport fit and zoom reset
            webView.scrollView.setZoomScale(1.0, animated: false)
            webView.scrollView.minimumZoomScale = 1.0
            webView.scrollView.maximumZoomScale = 1.0
        }
        
        // Capture thumbnail after load
        let config = WKSnapshotConfiguration()
        config.afterScreenUpdates = true
        webView.takeSnapshot(with: config) { image, _ in
            if let image = image { tab.snapshot = image }
        }
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        if webView == tabManager.activeTab?.webView { showSpinner(true) }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        webView.scrollView.refreshControl?.endRefreshing()
        showSpinner(false)
        if webView == tabManager.activeTab?.webView {
            let html = errorHTML(for: webView.url, error: error)
            webView.loadHTMLString(html, baseURL: nil)
        }
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        webView.scrollView.refreshControl?.endRefreshing()
        showSpinner(false)
        if webView == tabManager.activeTab?.webView {
            let html = errorHTML(for: webView.url, error: error)
            webView.loadHTMLString(html, baseURL: nil)
        }
    }
    
    // MARK: - WKUIDelegate
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
            webView.load(URLRequest(url: url))
        }
        return nil
    }
}
