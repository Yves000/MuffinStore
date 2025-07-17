import UIKit

@objc(AppDelegate)
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        let rootViewController = AppListViewController()
        let navigationController = UINavigationController(rootViewController: rootViewController)
        window?.rootViewController = navigationController
        window?.makeKeyAndVisible()
        
        // Setup Quick Actions
        setupQuickActions()
        
        // Handle Quick Action launch
        if let shortcutItem = launchOptions?[UIApplication.LaunchOptionsKey.shortcutItem] as? UIApplicationShortcutItem {
            handleQuickAction(shortcutItem)
        }
        
        return true
    }
    
    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        let handled = handleQuickAction(shortcutItem)
        completionHandler(handled)
    }
    
    private func setupQuickActions() {
        let downloadAction = UIApplicationShortcutItem(
            type: "download-app",
            localizedTitle: "Download App",
            localizedSubtitle: "Add new app to device",
            icon: UIApplicationShortcutIcon(systemImageName: "plus"),
            userInfo: nil
        )
        
        let searchAction = UIApplicationShortcutItem(
            type: "search-apps",
            localizedTitle: "Search Apps",
            localizedSubtitle: "Find installed apps",
            icon: UIApplicationShortcutIcon(systemImageName: "magnifyingglass"),
            userInfo: nil
        )
        
        UIApplication.shared.shortcutItems = [downloadAction, searchAction]
    }
    
    private func handleQuickAction(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
        switch shortcutItem.type {
        case "download-app":
            if let navigationController = window?.rootViewController as? UINavigationController,
               let appListVC = navigationController.topViewController as? AppListViewController {
                // Small delay to ensure the app is fully loaded
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    appListVC.triggerDownloadAction()
                }
                return true
            }
        case "search-apps":
            if let navigationController = window?.rootViewController as? UINavigationController,
               let appListVC = navigationController.topViewController as? AppListViewController {
                // Small delay to ensure the app is fully loaded
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    appListVC.triggerSearchAction()
                }
                return true
            }
        default:
            return false
        }
        return false
    }
}