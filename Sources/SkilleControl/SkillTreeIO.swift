import Foundation
import CryptoKit

/// Shared filesystem helpers for skill trees (digests, editor IO, diffs).
enum SkillTreeIO {
    static let textBufferLimitBytes = 512 * 1024

    static func absolutePath(_ url: URL) -> String {
        url.resolvingSymlinksInPath().standardizedFileURL.path
    }

    static func relativePath(of item: URL, under root: URL) -> String {
        let rootPath = absolutePath(root)
        let itemPath = absolutePath(item)
        if itemPath == rootPath { return "." }
        if itemPath.hasPrefix(rootPath + "/") {
            return String(itemPath.dropFirst(rootPath.count + 1))
        }
        return item.lastPathComponent
    }

    static func fileDigests(ofTree root: URL) throws -> [FileDigestRecord] {
        var digests: [FileDigestRecord] = []
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        for case let item as URL in enumerator {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: item.path, isDirectory: &isDir), !isDir.boolValue else {
                continue
            }
            let data = try Data(contentsOf: item)
            let hash = SHA256.hash(data: data)
            let hex = hash.map { String(format: "%02x", $0) }.joined()
            digests.append(
                FileDigestRecord(relPath: relativePath(of: item, under: root), sha256: hex)
            )
        }
        return digests.sorted { $0.relPath < $1.relPath }
    }

    static func looksLikeText(url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        let textExts: Set<String> = [
            "md", "txt", "json", "yml", "yaml", "toml", "swift", "py", "js", "ts",
            "sh", "zsh", "bash", "css", "html", "xml", "csv", "svg", "gitignore",
        ]
        if textExts.contains(ext) || url.lastPathComponent == "SKILL.md" {
            return true
        }
        if ext.isEmpty {
            guard let handle = try? FileHandle(forReadingFrom: url) else { return false }
            defer { try? handle.close() }
            return !handle.readData(ofLength: 512).contains(0)
        }
        return false
    }

    static func listFiles(at skillRootPath: String) throws -> [SkillFileEntry] {
        let root = URL(fileURLWithPath: skillRootPath, isDirectory: true)
        guard FileManager.default.fileExists(atPath: absolutePath(root)) else {
            throw EditorError.rootMissing
        }
        var entries: [SkillFileEntry] = []
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        for case let item as URL in enumerator {
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: item.path, isDirectory: &isDir),
                  !isDir.boolValue
            else { continue }
            entries.append(SkillFileEntry(relativePath: relativePath(of: item, under: root)))
        }
        return entries.sorted { $0.relativePath < $1.relativePath }
    }

    static func readText(at skillRootPath: String, relativePath: String) throws -> SkillFileContent {
        let url = try resolvedFileURL(skillRootPath: skillRootPath, relativePath: relativePath)
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let size = (attrs[.size] as? NSNumber)?.intValue ?? 0
        if !looksLikeText(url: url) {
            return SkillFileContent(relativePath: relativePath, byteSize: size, kind: .nonText)
        }
        if size > textBufferLimitBytes {
            return SkillFileContent(relativePath: relativePath, byteSize: size, kind: .tooLarge)
        }
        let text = try String(contentsOf: url, encoding: .utf8)
        return SkillFileContent(relativePath: relativePath, byteSize: size, kind: .text(text))
    }

    static func writeText(at skillRootPath: String, relativePath: String, content: String) throws {
        let url = try resolvedFileURL(skillRootPath: skillRootPath, relativePath: relativePath)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    static func absoluteFileURL(skillRootPath: String, relativePath: String) throws -> URL {
        try resolvedFileURL(skillRootPath: skillRootPath, relativePath: relativePath)
    }

    static func resolvedFileURL(skillRootPath: String, relativePath: String) throws -> URL {
        let root = URL(fileURLWithPath: skillRootPath, isDirectory: true)
            .resolvingSymlinksInPath()
            .standardizedFileURL
        let url = root.appendingPathComponent(relativePath).standardizedFileURL
        let rootPath = root.path
        guard url.path == rootPath || url.path.hasPrefix(rootPath + "/") else {
            throw EditorError.pathEscape
        }
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw EditorError.fileMissing
        }
        return url
    }

    static func diffTrees(local: URL, remote: URL) throws -> [UpdateFileChange] {
        let localDigests = Dictionary(
            uniqueKeysWithValues: (try fileDigests(ofTree: local)).map { ($0.relPath, $0) }
        )
        let remoteDigests = Dictionary(
            uniqueKeysWithValues: (try fileDigests(ofTree: remote)).map { ($0.relPath, $0) }
        )
        var changes: [UpdateFileChange] = []
        for path in Set(localDigests.keys).union(remoteDigests.keys).sorted() {
            let localHash = localDigests[path]?.sha256
            let remoteHash = remoteDigests[path]?.sha256
            if localHash == remoteHash { continue }

            let status: UpdateFileStatus =
                localHash == nil ? .added : remoteHash == nil ? .deleted : .modified
            let localURL = local.appendingPathComponent(path)
            let remoteURL = remote.appendingPathComponent(path)
            let localIsText = FileManager.default.fileExists(atPath: localURL.path)
                ? looksLikeText(url: localURL) : true
            let remoteIsText = FileManager.default.fileExists(atPath: remoteURL.path)
                ? looksLikeText(url: remoteURL) : true

            if localIsText && remoteIsText {
                let oldText = (try? String(contentsOf: localURL, encoding: .utf8)) ?? ""
                let newText = (try? String(contentsOf: remoteURL, encoding: .utf8)) ?? ""
                changes.append(
                    UpdateFileChange(
                        relativePath: path,
                        status: status,
                        textDiff: unifiedDiff(old: oldText, new: newText, path: path),
                        oldByteSize: nil,
                        newByteSize: nil
                    )
                )
            } else {
                changes.append(
                    UpdateFileChange(
                        relativePath: path,
                        status: status,
                        textDiff: nil,
                        oldByteSize: fileSize(localURL),
                        newByteSize: fileSize(remoteURL)
                    )
                )
            }
        }
        return changes
    }

    private static func fileSize(_ url: URL) -> Int? {
        guard FileManager.default.fileExists(atPath: url.path),
              let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? NSNumber
        else { return nil }
        return size.intValue
    }

    // ponytail: line-oriented mini diff; upgrade to lib if review UX needs hunks
    private static func unifiedDiff(old: String, new: String, path: String) -> String {
        let oldLines = old.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let newLines = new.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var out = "--- a/\(path)\n+++ b/\(path)\n"
        for i in 0..<max(oldLines.count, newLines.count) {
            let o = i < oldLines.count ? oldLines[i] : nil
            let n = i < newLines.count ? newLines[i] : nil
            if o == n, let o {
                out += " \(o)\n"
            } else {
                if let o { out += "-\(o)\n" }
                if let n { out += "+\(n)\n" }
            }
        }
        return out
    }
}
