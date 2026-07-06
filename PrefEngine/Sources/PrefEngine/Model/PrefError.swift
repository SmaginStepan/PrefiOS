import Foundation

/// Counterpart of the Kotlin/C# runtime exceptions thrown by the engine and AI.
/// The AI throws in rare positions by design; callers catch, log and continue.
public struct PrefError: Error, CustomStringConvertible {
    public let message: String

    public init(_ message: String) {
        self.message = message
    }

    public var description: String { message }
}
