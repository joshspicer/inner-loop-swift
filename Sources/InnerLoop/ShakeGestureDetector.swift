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
    private let ui = ShakeGestureUI()

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
            ui.showDebugMenu()
        }
    }
}
