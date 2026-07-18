import UIKit
import WebKit

class BrowserViewController: UIViewController, UITextFieldDelegate, WKNavigationDelegate, WKUIDelegate, TabOverviewDelegate, UITableViewDataSource, UITableViewDelegate {
    
    private let tabManager = TabManager()
    private var textField: UITextField!
    private var spinner: UIActivityIndicatorView!
    private var tabButton: UIButton!
    private var tabOverview: TabOverviewView!
    private var showingOverview = false
    
    // Search suggestions
    private var suggestionsTable: UITableView!
    private var suggestions: [String] = []
    private var suggestionTask: URLSessionDataTask?
    private var debounceTimer: Timer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .dark
        view.backgroundColor = UIColor(hex: 0x1C1C1E)
        
        setupTopBar()
        setupSuggestionsView()
        setupTabOverview()
        
        // Create first tab
        let tab = tabManager.addTab()
        tab.webView.navigationDelegate = self
        tab.webView.uiDelegate = self
        view.insertSubview(tab.webView, belowSubview: textField)
        pinWebView(tab.webView)
        
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
        view.addSubview(textField)
        
        spinner = UIActivityIndicatorView(style: .medium)
        spinner.color = UIColor(hex: 0x6CB4FF)
        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(spinner)
        
        tabButton = UIButton(type: .system)
        tabButton.backgroundColor = UIColor(hex: 0x3A3A3C)
        tabButton.layer.cornerRadius = 6
        tabButton.setTitleColor(.white, for: .normal)
        tabButton.titleLabel?.font = .systemFont(ofSize: 12, weight: .bold)
        tabButton.setTitle("1", for: .normal)
        tabButton.translatesAutoresizingMaskIntoConstraints = false
        tabButton.addTarget(self, action: #selector(showTabOverview), for: .touchUpInside)
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
            spinner.centerYAnchor.constraint(equalTo: textField.centerYAnchor),
            spinner.trailingAnchor.constraint(equalTo: tabButton.leadingAnchor, constant: -4),
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
        
        NSLayoutConstraint.activate([
            suggestionsTable.topAnchor.constraint(equalTo: textField.bottomAnchor, constant: 2),
            suggestionsTable.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            suggestionsTable.trailingAnchor.constraint(equalTo: tabButton.trailingAnchor),
            suggestionsTable.heightAnchor.constraint(equalToConstant: 200),
        ])
    }
    
    private func fetchSuggestions(for text: String) {
        suggestionTask?.cancel()
        guard !text.isEmpty else {
            hideSuggestions()
            return
        }
        
        let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text
        let urlString = "https://suggestqueries.google.com/complete/search?client=firefox&q=" + encoded
        
        guard let url = URL(string: urlString) else { return }
        
        suggestionTask = URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [Any],
                  json.count >= 2,
                  let items = json[1] as? [String] else { return }
            
            DispatchQueue.main.async {
                self.suggestions = items
                self.suggestionsTable.reloadData()
                self.suggestionsTable.isHidden = items.isEmpty
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
    
    // MARK: - Tab Overview
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
    
    private func pinWebView(_ webView: WKWebView) {
        webView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: textField.bottomAnchor, constant: 8),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }
    
    // MARK: - Tab Switching
    private func switchToActiveTab() {
        guard let activeTab = tabManager.activeTab else { return }
        
        for tab in tabManager.tabs {
            tab.webView.removeFromSuperview()
        }
        view.insertSubview(activeTab.webView, belowSubview: textField)
        pinWebView(activeTab.webView)
        
        textField.text = activeTab.webView.url?.absoluteString ?? activeTab.url
        if activeTab.webView.isLoading { spinner.startAnimating() } else { spinner.stopAnimating() }
        updateTabButton()
    }
    
    private func updateTabButton() {
        tabButton.setTitle("\(tabManager.tabCount)", for: .normal)
    }
    
    @objc private func showTabOverview() {
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
        let items = tabManager.tabs.map { tab in (id: tab.id, title: tab.title, url: tab.url) }
        tabOverview.updateTabs(items, activeId: tabManager.activeTabId)
    }
    
    // MARK: - TabOverviewDelegate
    func tabOverviewDidSelectTab(id: UUID) {
        tabManager.switchToTab(id: id)
        switchToActiveTab()
        hideOverview()
    }
    
    func tabOverviewDidCloseTab(id: UUID) {
        tabManager.closeTab(id: id)
        switchToActiveTab()
        refreshOverview()
    }
    
    func tabOverviewDidAddTab() {
        let tab = tabManager.addTab()
        tab.webView.navigationDelegate = self
        tab.webView.uiDelegate = self
        switchToActiveTab()
        hideOverview()
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
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        DispatchQueue.main.async { textField.selectAll(nil) }
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // Update text manually for debounce
        let currentText = textField.text ?? ""
        guard let stringRange = Range(range, in: currentText) else { return true }
        let updatedText = currentText.replacingCharacters(in: stringRange, with: string)
        
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            self?.fetchSuggestions(for: updatedText)
        }
        
        return true
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
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        spinner.stopAnimating()
        guard let tab = tabManager.tabs.first(where: { tab in tab.webView == webView }) else { return }
        tab.title = webView.title ?? "Untitled"
        tab.url = webView.url?.absoluteString ?? ""
        if webView == tabManager.activeTab?.webView {
            textField.text = webView.url?.absoluteString
        }
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        if webView == tabManager.activeTab?.webView { spinner.startAnimating() }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        spinner.stopAnimating()
        if webView == tabManager.activeTab?.webView {
            let html = errorHTML(for: webView.url, error: error)
            webView.loadHTMLString(html, baseURL: nil)
        }
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        spinner.stopAnimating()
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
