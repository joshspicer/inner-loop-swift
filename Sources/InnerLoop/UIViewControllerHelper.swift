import UIKit

/// Helper for finding the top view controller
enum UIViewControllerHelper {
    /// Get the top-most view controller in the app
    static func getTopViewController() -> UIViewController? {
        guard let windowScene = getActiveWindowScene(),
              let window = windowScene.windows.first(where: { $0.isKeyWindow }),
              let rootViewController = window.rootViewController else {
            return nil
        }

        return findTopViewController(from: rootViewController)
    }

    private static func getActiveWindowScene() -> UIWindowScene? {
        return UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
    }

    private static func findTopViewController(from viewController: UIViewController) -> UIViewController {
        if let presented = viewController.presentedViewController {
            return findTopViewController(from: presented)
        }

        if let navigationController = viewController as? UINavigationController,
           let topViewController = navigationController.topViewController {
            return findTopViewController(from: topViewController)
        }

        if let tabBarController = viewController as? UITabBarController,
           let selected = tabBarController.selectedViewController {
            return findTopViewController(from: selected)
        }

        return viewController
    }
}
