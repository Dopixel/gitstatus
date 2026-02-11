import Foundation

@Observable
final class GitMonitor {
    private var timer: Timer?
    private var cycleCount = 0
    private let store: RepoStore
    var isRefreshing = false

    init(store: RepoStore) {
        self.store = store
    }

    func start() {
        refresh()
        scheduleTimer()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func scheduleTimer() {
        timer?.invalidate()
        let interval = TimeInterval(store.config.pollIntervalMinutes * 60)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        cycleCount += 1
        let shouldFetch = (cycleCount % store.config.fetchEveryNthCycle) == 0
        let repos = store.enabledRepos

        Task.detached {
            var results: [String: RepoStatus] = [:]
            for repo in repos {
                let status = GitChecker.checkRepo(path: repo.path, fetch: shouldFetch)
                results[repo.path] = status
            }
            await MainActor.run { [results] in
                for (path, status) in results {
                    self.store.statuses[path] = status
                }
                self.isRefreshing = false
            }
        }
    }
}

// Fully nonisolated so git Process calls never touch the main actor
nonisolated enum GitChecker {
    static func checkRepo(path: String, fetch: Bool) -> RepoStatus {
        if fetch {
            _ = runGit(in: path, args: ["fetch", "--quiet"])
        }

        let porcelain = runGit(in: path, args: ["status", "--porcelain"])
        let hasUncommitted = !(porcelain?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)

        let revList = runGit(in: path, args: ["rev-list", "--left-right", "--count", "HEAD...@{upstream}"])
        var ahead = 0
        var behind = 0
        if let revList, !revList.isEmpty {
            let parts = revList.trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }
            if parts.count >= 2 {
                ahead = Int(parts[0]) ?? 0
                behind = Int(parts[1]) ?? 0
            }
        }

        let branchOutput = runGit(in: path, args: ["symbolic-ref", "--short", "HEAD"])
        let branch = branchOutput?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown"
        let onDefault = (branch == "main" || branch == "master")

        let state: RepoState
        if behind > 0 {
            state = .behind
        } else if ahead > 0 {
            state = .notPushed
        } else if hasUncommitted {
            state = .uncommitted
        } else {
            state = .clean
        }

        return RepoStatus(state: state, onDefaultBranch: onDefault, currentBranch: branch, lastChecked: Date())
    }

    private static func runGit(in directory: String, args: [String]) -> String? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", directory] + args
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }
}
