import UIKit
import SwiftUI

/// Handles presenting UI alerts and dialogs for the shake gesture detector
class ShakeGestureUI {
    private let logger = Logger.shared

    /// Show the main debug menu (full-screen console on iOS 15+, fallback to action sheet)
    func showDebugMenu() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Use full-screen SwiftUI debug console on iOS 15+
            if #available(iOS 15.0, *) {
                self.showDebugConsole()
            } else {
                self.showLegacyDebugMenu()
            }
        }
    }
    
    /// Show the beautiful full-screen debug console (iOS 15+)
    @available(iOS 15.0, *)
    private func showDebugConsole() {
        guard let topController = UIViewControllerHelper.getTopViewController() else {
            logger.warning("DebugConsole", "Could not find top view controller")
            return
        }
        
        let debugConsole = DebugConsoleHostingController()
        debugConsole.modalPresentationStyle = .fullScreen
        debugConsole.modalTransitionStyle = .coverVertical
        
        topController.present(debugConsole, animated: true) {
            self.logger.info("DebugConsole", "Debug console presented")
        }
    }
    
    /// Legacy action sheet debug menu for older iOS versions
    private func showLegacyDebugMenu() {
        let alert = UIAlertController(
            title: "Debug Menu",
            message: "InnerLoop Debug Options",
            preferredStyle: .actionSheet
        )

        alert.addAction(UIAlertAction(title: "Send Logs with Message", style: .default) { [weak self] _ in
            self?.promptForUserMessage()
        })

        let bufferSize = LogBatcher.shared.getBufferSize()
        alert.addAction(UIAlertAction(title: "Send Logs (\(bufferSize) buffered)", style: .default) { [weak self] _ in
            self?.logger.info("Sending buffered logs")
            LogBatcher.shared.sendBatch()
        })

        alert.addAction(UIAlertAction(title: "View Buffer Size", style: .default) { [weak self] _ in
            let size = LogBatcher.shared.getBufferSize()
            self?.logger.info("Current buffer size: \(size) logs")
            self?.showBufferInfo(size: size)
        })

        alert.addAction(UIAlertAction(title: "Test Error Reporting", style: .default) { [weak self] _ in
            self?.logger.info("Testing error reporting")
            ErrorHandler.shared.report(message: "Test error from debug menu")
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let topController = UIViewControllerHelper.getTopViewController() {
            // For iPad support
            if let popoverController = alert.popoverPresentationController {
                popoverController.sourceView = topController.view
                popoverController.sourceRect = CGRect(x: topController.view.bounds.midX, y: topController.view.bounds.midY, width: 0, height: 0)
                popoverController.permittedArrowDirections = []
            }
            topController.present(alert, animated: true)
        }
    }

    /// Prompt user for message to send with logs
    func promptForUserMessage() {
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

            if let topController = UIViewControllerHelper.getTopViewController() {
                topController.present(alert, animated: true)
            }
        }
    }

    /// Show buffer size info
    func showBufferInfo(size: Int) {
        DispatchQueue.main.async {
            let alert = UIAlertController(
                title: "Buffer Info",
                message: "\(size) logs are currently buffered and will be sent automatically or when you send them manually.",
                preferredStyle: .alert
            )

            alert.addAction(UIAlertAction(title: "OK", style: .default))

            if let topController = UIViewControllerHelper.getTopViewController() {
                topController.present(alert, animated: true)
            }
        }
    }
}
