import Foundation

enum AppGroupConstants: Sendable {
    nonisolated static let identifier = "group.com.zuvano.app"
    nonisolated static let handoffDirectoryName = "zuvano-handoff"
    nonisolated static let urlScheme = "zuvano"
    nonisolated static let handoffHost = "handoff"
    /// Handoff files older than this are deleted on stale sweep.
    nonisolated static let handoffMaxAge: TimeInterval = 24 * 60 * 60
}
