import Foundation

/// Build-time configuration injected through Info.plist (see Config/*.xcconfig).
/// Unset or unsubstituted values (a literal "$(...)") read as nil.
enum PrefConfig {
    static func string(_ key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty || trimmed.hasPrefix("$(") ? nil : trimmed
    }
}
