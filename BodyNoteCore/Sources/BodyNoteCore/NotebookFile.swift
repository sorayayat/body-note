import Foundation

public final class NotebookFile {
    public let url: URL
    public let media: JournalAttachmentStore
    private let fileLock = NSLock()
    private var savedMediaFiles: Set<String>?

    private struct Document: Codable {
        static let currentVersion = 4
        let version: Int
        let notebook: Notebook

        init(notebook: Notebook) {
            self.version = Self.currentVersion
            self.notebook = notebook
        }

        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            version = try values.decode(Int.self, forKey: .version)
            guard (1...Self.currentVersion).contains(version) else { throw NotebookError.unsupportedFile }
            notebook = try values.decode(Notebook.self, forKey: .notebook)
        }
    }

    public init(url: URL) {
        self.url = url
        self.media = JournalAttachmentStore(directory: url.appendingPathExtension("media"))
    }

    public func load() throws -> Notebook {
        fileLock.lock()
        defer { fileLock.unlock() }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return Notebook()
        }
        let document = try JSONDecoder().decode(Document.self, from: data)
        var notebook = document.notebook
        notebook.restoreRecordAppearances()
        let files = media.referencedFiles(in: notebook)
        media.collectOrphans(keeping: files)
        savedMediaFiles = files
        return notebook
    }

    public func save(_ notebook: Notebook) throws {
        fileLock.lock()
        defer { fileLock.unlock() }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(Document(notebook: notebook))
        #if os(iOS)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        #else
        try data.write(to: url, options: .atomic)
        #endif
        // Release old assets only once the replacement journal is safely on disk.
        let files = media.referencedFiles(in: notebook)
        if let previous = savedMediaFiles { media.removeFiles(previous.subtracting(files)) }
        savedMediaFiles = files
    }
}
