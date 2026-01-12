import Foundation

/// Utility functions for InnerLoop
enum MetadataUtil {
    /// Build metadata dictionary from configuration
    static func buildMetadata(from configuration: InnerLoopConfiguration, additionalInfo: [String: String] = [:]) -> [String: String] {
        var metadata = additionalInfo

        for (key, value) in configuration.metadata {
            if let stringValue = value as? String {
                metadata[key] = stringValue
            } else if let customStringConvertible = value as? CustomStringConvertible {
                metadata[key] = customStringConvertible.description
            } else {
                metadata[key] = "\(value)"
            }
        }

        return metadata
    }
}
