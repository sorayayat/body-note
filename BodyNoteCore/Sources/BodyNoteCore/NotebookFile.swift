import Foundation

public struct NotebookFile {
    public let url: URL

    private struct Document: Codable {
        static let currentVersion = 3
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

    public init(url: URL) { self.url = url }

    public func load() throws -> Notebook {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return Notebook()
        }
        let document = try JSONDecoder().decode(Document.self, from: data)
        var notebook = document.notebook
        notebook.restoreRecordAppearances()
        return notebook
    }

    public func save(_ notebook: Notebook) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(Document(notebook: notebook))
        #if os(iOS)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        #else
        try data.write(to: url, options: .atomic)
        #endif
    }
}
