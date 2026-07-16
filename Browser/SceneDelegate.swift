import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = MainViewController()
        window?.makeKeyAndVisible()
        
        // Set window tint color
        window?.tintColor = UIColor(hex: 0x4285F4)
    }
    
    func sceneWillResignActive(_ scene: UIScene) {
        CookieManager.shared.saveCookies()
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        CookieManager.shared.restoreCookies()
    }
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        CookieManager.shared.saveCookies()
    }
}
