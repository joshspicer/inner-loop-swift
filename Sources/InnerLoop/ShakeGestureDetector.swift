import UIKit

/// Delegate protocol for shake gesture events
public protocol ShakeGestureDelegate: AnyObject {
    func didDetectShakeGesture()
}

/// Shake gesture detector for debugging
public class ShakeGestureDetector {
    public static let shared = ShakeGestureDetector()
    
    public weak var delegate: ShakeGestureDelegate?
    private var isEnabled = false
    private let logger = Logger.shared
    
    private init() {}
    
    /// Enable shake gesture detection
    public func enable() {
        isEnabled = true
        logger.debug("Shake gesture detection enabled")
    }
    
    /// Disable shake gesture detection
    public func disable() {
        isEnabled = false
        logger.debug("Shake gesture detection disabled")
    }
    
    /// Call this method from your UIWindow or UIViewController's motionEnded method
    public func handleMotion(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        guard isEnabled, motion == .motionShake else { return }
        
        logger.info("Shake gesture detected")
        delegate?.didDetectShakeGesture()
        
        // Show debug menu if no delegate is set
        if delegate == nil {
            showDebugMenu()
        }
    }
    
    private func showDebugMenu() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let alert = UIAlertController(
                title: "Debug Menu",
                message: "InnerLoop Debug Options",
                preferredStyle: .actionSheet
            )
            
            alert.addAction(UIAlertAction(title: "View Logs", style: .default) { _ in
                self.logger.info("View Logs selected")
                // Custom implementation can be added via delegate
            })
            
            alert.addAction(UIAlertAction(title: "Clear Cache", style: .default) { _ in
                self.logger.info("Clear Cache selected")
                // Custom implementation can be added via delegate
            })
            
            alert.addAction(UIAlertAction(title: "Test Error Reporting", style: .default) { _ in
                self.logger.info("Testing error reporting")
                ErrorHandler.shared.report(message: "Test error from debug menu")
            })
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            
            if let topController = self.getTopViewController() {
                // For iPad support
                if let popoverController = alert.popoverPresentationController {
                    popoverController.sourceView = topController.view
                    popoverController.sourceRect = CGRect(x: topController.view.bounds.midX, y: topController.view.bounds.midY, width: 0, height: 0)
                    popoverController.permittedArrowDirections = []
                }
                topController.present(alert, animated: true)
            }
        }
    }
    
    private func getTopViewController() -> UIViewController? {
        // Use the first connected scene and find its key window
        guard let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }) else {
            return nil
        }
        
        guard let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            return nil
        }
        
        guard let rootViewController = window.rootViewController else {
            return nil
        }
        
        return findTopViewController(from: rootViewController)
    }
    
    private func findTopViewController(from viewController: UIViewController) -> UIViewController {
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
