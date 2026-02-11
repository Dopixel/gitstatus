import Foundation

enum RepoScanner {
    nonisolated static func scanDirectory(_ path: String) -> [String] {
        let fm = FileManager.default
        var repos: [String] = []

        guard let enumerator = fm.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return repos
        }

        for case let url as URL in enumerator {
            let gitDir = url.appendingPathComponent(".git")
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: gitDir.path, isDirectory: &isDir), isDir.boolValue {
                repos.append(url.path)
                enumerator.skipDescendants()
            }
        }

        return repos.sorted()
    }
}
