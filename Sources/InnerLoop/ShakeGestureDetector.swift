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

            alert.addAction(UIAlertAction(title: "Send Logs with Message", style: .default) { _ in
                self.promptForUserMessage()
            })

            let bufferSize = LogBatcher.shared.getBufferSize()
            alert.addAction(UIAlertAction(title: "Send Logs (\(bufferSize) buffered)", style: .default) { _ in
                self.logger.info("Sending buffered logs")
                LogBatcher.shared.sendBatch()
            })

            alert.addAction(UIAlertAction(title: "View Buffer Size", style: .default) { _ in
                let size = LogBatcher.shared.getBufferSize()
                self.logger.info("Current buffer size: \(size) logs")
                self.showBufferInfo(size: size)
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

    private func promptForUserMessage() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let alert = UIAlertController(
                title: "Add Context",
                message: "Describe what you were doing or what went wrong:",
                preferredStyle: .alert
            )

            alert.addTextField { textField in
                textField.placeholder = "e.g., 'App crashed when tapping save button'"
                textField.autocapitalizationType = .sentences
            }

            alert.addAction(UIAlertAction(title: "Send", style: .default) { _ in
                let message = alert.textFields?.first?.text ?? ""
                self.logger.info("Sending logs with user message: \(message)")
                LogBatcher.shared.sendBatch(userMessage: message.isEmpty ? nil : message)
            })

            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

            if let topController = self.getTopViewController() {
                topController.present(alert, animated: true)
            }
        }
    }

    private func showBufferInfo(size: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let alert = UIAlertController(
                title: "Buffer Info",
                message: "\(size) logs are currently buffered and will be sent automatically or when you send them manually.",
                preferredStyle: .alert
            )

            alert.addAction(UIAlertAction(title: "OK", style: .default))

            if let topController = self.getTopViewController() {
                topController.present(alert, animated: true)
            }
        }
    }
    
    private func getTopViewController() -> UIViewController? {
        guard let windowScene = getActiveWindowScene(),
              let window = windowScene.windows.first(where: { $0.isKeyWindow }),
              let rootViewController = window.rootViewController else {
            return nil
        }
        
        return findTopViewController(from: rootViewController)
    }
    
    private func getActiveWindowScene() -> UIWindowScene? {
        return UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
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
