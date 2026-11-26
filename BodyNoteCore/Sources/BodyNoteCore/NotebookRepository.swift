import Foundation

public protocol NotebookRepository {
    func load() throws -> Notebook
    func save(_ notebook: Notebook) throws
}

extension NotebookFile: NotebookRepository {}

public extension NotebookRepository {
    /// Publish the returned snapshot only after the local write succeeds.
    func applying(to current: Notebook, _ change: (inout Notebook) throws -> Void) throws -> Notebook {
        var next = current
        try change(&next)
        // The caller may hold newer, memory-only input after a failed autosave.
        try save(next)
        return next
    }
}
