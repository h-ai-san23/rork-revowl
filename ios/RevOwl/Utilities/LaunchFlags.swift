import Foundation

/// Launch arguments used only by UI tests. Normal launches never pass them.
nonisolated enum LaunchFlags {
    /// `-uitestReset`: start signed out with no saved property.
    static let resetForUITests = ProcessInfo.processInfo.arguments.contains("-uitestReset")
    /// `-uitestStill`: draw Orev without continuous animation so UI tests can reach an idle state.
    static let stillOrev = ProcessInfo.processInfo.arguments.contains("-uitestStill")
}
