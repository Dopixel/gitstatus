import Foundation

enum RepoState: Int, Codable, Comparable {
    case clean = 0
    case uncommitted = 1
    case notPushed = 2
    case behind = 3

    static func < (lhs: RepoState, rhs: RepoState) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var label: String {
        switch self {
        case .clean: "Clean"
        case .uncommitted: "Uncommitted changes"
        case .notPushed: "Not pushed"
        case .behind: "Behind remote"
        }
    }

    var color: String {
        switch self {
        case .clean: "green"
        case .uncommitted: "yellow"
        case .notPushed: "orange"
        case .behind: "red"
        }
    }
}

enum OpenWith: Codable, Equatable {
    case terminal
    case ghostty
    case finder
    case custom(path: String)
}

struct TrackedRepo: Codable, Identifiable, Equatable {
    var id: String { path }
    var path: String
    var displayName: String
    var enabled: Bool
}

struct AppConfig: Codable {
    var scanDirectories: [String] = []
    var trackedRepos: [TrackedRepo] = []
    var pollIntervalMinutes: Int = 5
    var launchAtLogin: Bool = false
    var openWith: OpenWith = .terminal
    var fetchEveryNthCycle: Int = 3
}

struct RepoStatus {
    var state: RepoState = .clean
    var onDefaultBranch: Bool = false
    var currentBranch: String = "unknown"
    var lastChecked: Date? = nil
    /// Set when git could not be run or failed, so the real state is unknown (never show it as clean).
    var error: String? = nil
    /// Set when `git fetch` failed, so "behind" information may be stale.
    var fetchWarning: String? = nil
}
