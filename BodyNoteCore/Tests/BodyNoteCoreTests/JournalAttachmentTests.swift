import Foundation
import XCTest
@testable import BodyNoteCore

final class JournalAttachmentTests: XCTestCase {
    private func withFile(_ test: (NotebookFile) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try test(NotebookFile(url: directory.appendingPathComponent("journal.json")))
    }

    func testDraftAndConfirmedEntryShareMediaWithoutCopyingItIntoTheJSONOrRoutine() throws {
        try withFile { file in
            var book = Notebook()
            let photo = JournalAttachment(kind: .photo)
            let drawing = JournalAttachment(kind: .drawing)
            let photoBytes = Data(repeating: 217, count: 128)
            let drawingBytes = Data([137, 80, 78, 71])
            try file.media.write(photoBytes, for: photo)
            try file.media.write(drawingBytes, for: drawing)
            XCTAssertThrowsError(try file.media.write(drawingBytes, for: photo))
            var draft = WorkoutDraft(JournalEntry(exercises: [Exercise(name: "스쿼트")]))
            let field = "weight-\(draft.entry.exercises[0].sets[0].id)"
            draft.numbers[field] = "17."
            draft.entry.attachments = [photo, drawing]
            book.keepDraft(draft)
            try file.save(book)

            book = try file.load()
            XCTAssertEqual(book.drafts.first?.entry.attachments, [photo, drawing])
            XCTAssertEqual(book.drafts.first?.numbers[field], "17.")
            XCTAssertEqual(try file.media.read(photo), photoBytes)
            XCTAssertEqual(book.xp, 0)
            let json = try String(contentsOf: file.url, encoding: .utf8)
            XCTAssertFalse(json.contains(photoBytes.base64EncodedString()))

            try book.confirm(draft.resolvedEntry())
            try file.save(book)
            let reopened = try NotebookFile(url: file.url).load()
            let entry = try XCTUnwrap(reopened.entries.first)
            XCTAssertEqual(entry.attachments, [photo, drawing])
            XCTAssertEqual(try file.media.read(drawing), drawingBytes)
            XCTAssertEqual(reopened.xp, 10)
            XCTAssertTrue(reopened.drafts.isEmpty)
            XCTAssertTrue(entry.draftForToday().attachments.isEmpty)
            try book.saveRoutine(name: "하체", kind: .training, exercises: entry.exercises)
            XCTAssertTrue(book.newTrainingDraft().attachments.isEmpty)
        }
    }

    func testDiscardingAnEditKeepsTheOriginalAndReleasesOnlyUnreferencedFiles() throws {
        try withFile { file in
            let original = JournalAttachment(kind: .photo)
            let replacement = JournalAttachment(kind: .drawing)
            try file.media.write(Data([1]), for: original)
            var entry = JournalEntry(kind: .rest)
            entry.attachments = [original]
            var book = Notebook()
            try book.confirm(entry)
            try file.save(book)

            var edit = WorkoutDraft(entry)
            let sketchID = UUID()
            edit.drawingID = sketchID
            edit.entry.attachments = [replacement]
            try file.media.write(Data([2]), for: replacement)
            book.keepDraft(edit)
            try file.save(book)
            try file.media.saveDrawingDraft(Data([3]), for: sketchID)
            XCTAssertEqual(try file.media.drawingDraft(for: sketchID), Data([3]))
            XCTAssertEqual(try file.load().entries.first?.attachments, [original])
            XCTAssertEqual(try file.media.read(original), Data([1]))

            book.removeDraft(edit.id)
            try file.save(book)
            XCTAssertEqual(try file.media.read(original), Data([1]))
            XCTAssertThrowsError(try file.media.read(replacement))
            XCTAssertNil(try file.media.drawingDraft(for: sketchID))
            entry.attachments = []
            try book.confirm(entry)
            try file.save(book)
            XCTAssertThrowsError(try file.media.read(original))
        }
    }

    func testFinishingSketchAtomicallyTradesScratchForOneAttachment() throws {
        try withFile { file in
            var book = Notebook()
            var draft = WorkoutDraft(JournalEntry(kind: .rest))
            let sketchID = UUID()
            draft.drawingID = sketchID
            book.keepDraft(draft)
            try file.save(book)
            let strokes = Data([9, 8, 7])
            try file.media.saveDrawingDraft(strokes, for: sketchID)
            let rendered = JournalAttachment(kind: .drawing)
            try file.media.write(Data([6]), for: rendered)
            draft.entry.attachments = [rendered]
            draft.drawingID = nil
            book.keepDraft(draft)
            try file.save(book)
            XCTAssertFalse(file.media.hasDrawingDraft(for: sketchID))
            XCTAssertNoThrow(try file.media.saveDrawingDraft(nil, for: sketchID))

            // Simulate termination after the metadata commit but before deleting the scratch file.
            try file.media.saveDrawingDraft(strokes, for: sketchID)
            let reopened = try file.load()
            XCTAssertEqual(reopened.drafts.first?.entry.attachments, [rendered])
            XCTAssertNil(reopened.drafts.first?.drawingID)
            XCTAssertFalse(file.media.hasDrawingDraft(for: sketchID))
            XCTAssertEqual(reopened.xp, 0)
        }
    }

    func testFailedMetadataWriteAndUnreadableJournalKeepTheMedia() throws {
        try withFile { file in
            let photo = JournalAttachment(kind: .photo)
            var entry = JournalEntry(kind: .rest)
            entry.attachments = [photo]
            try file.media.write(Data([4]), for: photo)
            var book = Notebook()
            try book.confirm(entry)
            try file.save(book)
            let saved = try Data(contentsOf: file.url)
            try FileManager.default.removeItem(at: file.url)
            try FileManager.default.createDirectory(at: file.url, withIntermediateDirectories: false)
            entry.attachments = []
            try book.confirm(entry)
            XCTAssertThrowsError(try file.save(book))
            XCTAssertEqual(try file.media.read(photo), Data([4]))

            try FileManager.default.removeItem(at: file.url)
            let orphan = JournalAttachment(kind: .photo)
            try file.media.write(Data([5]), for: orphan)
            try Data(#"{"version":99,"notebook":{}}"#.utf8).write(to: file.url)
            XCTAssertThrowsError(try file.load())
            XCTAssertEqual(try file.media.read(orphan), Data([5]))
            try saved.write(to: file.url)
            let otherFile = file.media.directory.appendingPathComponent("untouched.txt")
            try Data([6]).write(to: otherFile)
            XCTAssertEqual(try file.load().entries.first?.attachments, [photo])
            XCTAssertEqual(try file.media.read(photo), Data([4]))
            XCTAssertThrowsError(try file.media.read(orphan))
            XCTAssertEqual(try Data(contentsOf: otherFile), Data([6]))
        }
    }

    func testV3JournalOpensAndUpgradesWithAnAttachment() throws {
        try withFile { file in
            var book = Notebook()
            try book.confirm(JournalEntry(kind: .rest))
            let old = try JSONSerialization.jsonObject(with: JSONEncoder().encode(book))
            let bytes = try JSONSerialization.data(withJSONObject: ["version": 3, "notebook": old])
            try FileManager.default.createDirectory(at: file.url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try bytes.write(to: file.url)
            book = try file.load()
            XCTAssertEqual(try Data(contentsOf: file.url), bytes)
            var entry = try XCTUnwrap(book.entries.first)
            XCTAssertTrue(entry.attachments.isEmpty)
            let photo = JournalAttachment(kind: .photo)
            try file.media.write(Data([7]), for: photo)
            entry.attachments = [photo]
            try book.confirm(entry)
            try file.save(book)
            XCTAssertEqual(try file.load().entries.first?.attachments, [photo])
            let envelope = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: file.url)) as? [String: Any])
            XCTAssertEqual(envelope["version"] as? Int, 4)
        }
    }
}
