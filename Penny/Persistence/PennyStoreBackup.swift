import Foundation

/// Copies a SwiftData store (and its WAL/SHM sidecars) aside, and puts that copy back.
///
/// Migration uses this before opening an existing store. A later Backup & Restore
/// feature can call the same copy and restore functions for a user-chosen file.
enum PennyStoreBackup {
    static func backupRoot(for storeURL: URL) -> URL {
        storeURL.deletingLastPathComponent()
            .appendingPathComponent("PennyBackups", isDirectory: true)
            .appendingPathComponent(storeURL.lastPathComponent, isDirectory: true)
    }

    static func snapshotDirectory(for storeURL: URL) -> URL {
        backupRoot(for: storeURL).appendingPathComponent("pre-migration", isDirectory: true)
    }

    static func markerURL(for storeURL: URL) -> URL {
        backupRoot(for: storeURL).appendingPathComponent("migration-in-progress")
    }

    /// `Penny.store`, `Penny.store-wal`, and `Penny.store-shm`.
    static func relatedURLs(for storeURL: URL) -> [URL] {
        let path = storeURL.path
        return [
            storeURL,
            URL(fileURLWithPath: path + "-wal"),
            URL(fileURLWithPath: path + "-shm")
        ]
    }

    static func storeExists(at storeURL: URL) -> Bool {
        relatedURLs(for: storeURL).contains { FileManager.default.fileExists(atPath: $0.path) }
    }

    static func copyStore(at storeURL: URL, to directory: URL) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        for file in try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            try fileManager.removeItem(at: file)
        }
        var copied = false
        for url in relatedURLs(for: storeURL) where fileManager.fileExists(atPath: url.path) {
            try fileManager.copyItem(at: url, to: directory.appendingPathComponent(url.lastPathComponent))
            copied = true
        }
        guard copied else {
            throw CocoaError(.fileNoSuchFile)
        }
    }

    static func restore(from directory: URL, over storeURL: URL) throws {
        let fileManager = FileManager.default
        for url in relatedURLs(for: storeURL) where fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
        let files = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        let parent = storeURL.deletingLastPathComponent()
        for file in files {
            let destination = parent.appendingPathComponent(file.lastPathComponent)
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.copyItem(at: file, to: destination)
        }
    }

    static func discard(storeAt storeURL: URL) {
        let fileManager = FileManager.default
        let root = backupRoot(for: storeURL)
        try? fileManager.removeItem(at: root)
    }
}
