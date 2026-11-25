import Foundation

public struct NotebookFile {
    public let url: URL

    private struct Document: Codable {
        let version: Int
        let notebook: Notebook
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
        guard document.version == 1 else { throw NotebookError.unsupportedFile }
        var notebook = document.notebook
        notebook.restoreRecordAppearances()
        return notebook
    }

    public func save(_ notebook: Notebook) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(Document(version: 1, notebook: notebook))
        #if os(iOS)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        #else
        try data.write(to: url, options: .atomic)
        #endif
    }
}
