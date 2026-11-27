import Foundation

public struct JournalAttachment: Identifiable, Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case photo, drawing }

    public let id: UUID
    public let kind: Kind

    public init(id: UUID = UUID(), kind: Kind) {
        self.id = id
        self.kind = kind
    }

    fileprivate var fileName: String {
        id.uuidString + (kind == .photo ? ".jpg" : ".png")
    }
}

/// The journal contains only references. Media lives alongside its owning notebook.
public struct JournalAttachmentStore: Sendable {
    public let directory: URL

    public init(directory: URL) { self.directory = directory }

    public func url(for attachment: JournalAttachment) -> URL {
        directory.appendingPathComponent(attachment.fileName)
    }

    public func read(_ attachment: JournalAttachment) throws -> Data {
        try Data(contentsOf: url(for: attachment))
    }

    public func write(_ imageData: Data, for attachment: JournalAttachment) throws {
        guard !imageData.isEmpty else { throw CocoaError(.fileWriteUnknown) }
        // The caller publishes this UUID only after the write finishes. Existing
        // files stay immutable even if two callers accidentally reuse an ID.
        try writeFile(imageData, to: url(for: attachment), options: .withoutOverwriting)
    }

    private func drawingFile(for id: UUID) -> URL {
        directory.appendingPathComponent(id.uuidString + ".pkdrawing")
    }

    public func hasDrawingDraft(for id: UUID) -> Bool {
        FileManager.default.fileExists(atPath: drawingFile(for: id).path)
    }

    public func drawingDraft(for id: UUID) throws -> Data? {
        do { return try Data(contentsOf: drawingFile(for: id)) }
        catch let error as CocoaError where error.code == .fileReadNoSuchFile { return nil }
    }

    public func saveDrawingDraft(_ data: Data?, for id: UUID) throws {
        let file = drawingFile(for: id)
        if let data {
            try writeFile(data, to: file, options: .atomic)
        } else {
            do { try FileManager.default.removeItem(at: file) }
            catch let error as CocoaError where error.code == .fileNoSuchFile { return }
        }
    }

    private func writeFile(_ data: Data, to file: URL, options: Data.WritingOptions) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        #if os(iOS)
        try data.write(to: file, options: options.union(.completeFileProtection))
        #else
        try data.write(to: file, options: options)
        #endif
    }

    func referencedFiles(in notebook: Notebook) -> Set<String> {
        var names = Set(notebook.entries.flatMap { $0.attachments.map(\.fileName) })
        for draft in notebook.drafts where draft.purpose == .journal {
            names.formUnion(draft.entry.attachments.map(\.fileName))
            if let id = draft.drawingID { names.insert(drawingFile(for: id).lastPathComponent) }
        }
        return names
    }

    func removeFiles(_ names: Set<String>) {
        for name in names { try? FileManager.default.removeItem(at: directory.appendingPathComponent(name)) }
    }

    // Recover files left between a media write and a journal commit, but only after
    // a successful notebook load. A locked, corrupt or newer journal keeps its files.
    func collectOrphans(keeping names: Set<String>) {
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory,
            includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else { return }
        for file in files where !names.contains(file.lastPathComponent) {
            guard ["jpg", "png", "pkdrawing"].contains(file.pathExtension),
                  UUID(uuidString: file.deletingPathExtension().lastPathComponent) != nil,
                  (try? file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { continue }
            try? FileManager.default.removeItem(at: file)
        }
    }
}
