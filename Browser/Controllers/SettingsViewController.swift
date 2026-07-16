import UIKit

class SettingsViewController: UIViewController {
    
    private let settingsView = SettingsView()
    
    var onDismiss: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        
        settingsView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(settingsView)
        
        NSLayoutConstraint.activate([
            settingsView.topAnchor.constraint(equalTo: view.topAnchor),
            settingsView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            settingsView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            settingsView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        settingsView.delegate = self
    }
}

extension SettingsViewController: SettingsViewDelegate {
    func settingsViewDidDismiss(_ settingsView: SettingsView) {
        onDismiss?()
        dismiss(animated: true)
    }
}
