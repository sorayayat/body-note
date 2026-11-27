import SwiftUI
import CoreTransferable
import ImageIO
import UniformTypeIdentifiers
import BodyNoteCore

struct JournalPickerPhoto: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .image) { received in
            // The picker's temporary file is only valid during this import closure.
            guard let image = attachmentImage(at: received.file, maxPixelSize: 2_048) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            let encoded = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(encoded as CFMutableData,
                                                                     UTType.jpeg.identifier as CFString, 1, nil)
            else { throw CocoaError(.fileWriteUnknown) }
            let options: [CFString: Any] = [
                kCGImageDestinationLossyCompressionQuality: 0.85,
                kCGImageDestinationBackgroundColor: CGColor(gray: 1, alpha: 1)
            ]
            CGImageDestinationAddImage(destination, image, options as CFDictionary)
            guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
            return JournalPickerPhoto(data: encoded as Data)
        }
    }
}

private func attachmentImage(at url: URL, maxPixelSize: Int) -> CGImage? {
    let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
    guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else { return nil }
    let options: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceShouldCacheImmediately: true,
        kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
    ]
    return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
}

private extension JournalAttachment {
    var label: String { kind == .photo ? "사진" : "그림" }
    var symbol: String { kind == .photo ? "photo" : "pencil.tip" }
}

struct JournalAttachmentGrid: View {
    @EnvironmentObject private var store: JournalStore
    let attachments: [JournalAttachment]
    var onRemove: ((JournalAttachment) throws -> Void)? = nil
    @State private var preview: JournalAttachment?

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100, maximum: 180), spacing: 12)],
                  alignment: .leading, spacing: 12) {
            ForEach(Array(attachments.enumerated()), id: \.element.id) { index, attachment in
                Button {
                    preview = attachment
                } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        AttachmentImageView(url: store.media.url(for: attachment), thumbnail: true)
                            .aspectRatio(4.0 / 3.0, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        Label("\(attachment.label) \(index + 1)", systemImage: attachment.symbol)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(attachment.label) \(index + 1) 보기")
                .accessibilityIdentifier("journal.attachment.thumbnail.\(attachment.kind.rawValue)")
            }
        }
        .padding(.vertical, 4)
        .sheet(item: $preview) { item in
            NavigationStack {
                AttachmentPreview(attachment: item, url: store.media.url(for: item), onRemove: onRemove)
            }
        }
    }
}

private struct AttachmentImageView: View {
    let url: URL
    let thumbnail: Bool
    @State private var image: CGImage?
    @State private var failed = false

    var body: some View {
        ZStack {
            Color(uiColor: .secondarySystemBackground)
            if let image {
                GeometryReader { geometry in
                    Image(image, scale: 1, label: Text("첨부 이미지"))
                        .resizable().aspectRatio(contentMode: thumbnail ? .fill : .fit)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                        .accessibilityHidden(thumbnail)
                        .accessibilityIdentifier("journal.attachment.image")
                }
            } else if failed {
                Label("첨부를 열 수 없어요", systemImage: "photo")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                ProgressView()
            }
        }
        .task(id: url) {
            image = nil
            failed = false
            let size = thumbnail ? 420 : 2_048
            let file = url
            let decoded = await Task.detached(priority: .userInitiated) {
                attachmentImage(at: file, maxPixelSize: size)
            }.value
            guard !Task.isCancelled else { return }
            image = decoded
            failed = decoded == nil
        }
    }
}

private struct AttachmentPreview: View {
    @Environment(\.dismiss) private var dismiss
    let attachment: JournalAttachment
    let url: URL
    let onRemove: ((JournalAttachment) throws -> Void)?
    @State private var confirmingRemoval = false
    @State private var error: String?

    var body: some View {
        AttachmentImageView(url: url, thumbnail: false)
            .navigationTitle("\(attachment.label) 보기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                        .accessibilityIdentifier("journal.attachment.close")
                }
                if let onRemove {
                    ToolbarItem(placement: .primaryAction) {
                        Button(role: .destructive) { confirmingRemoval = true } label: {
                            Label("첨부 제거", systemImage: "trash")
                        }
                        .accessibilityIdentifier("journal.attachment.remove")
                        .confirmationDialog("선택한 첨부를 일지에서 뺄까요?", isPresented: $confirmingRemoval,
                                            titleVisibility: .visible) {
                            Button("일지에서 빼기", role: .destructive) {
                                do { try onRemove(attachment); dismiss() }
                                catch { self.error = error.localizedDescription }
                            }
                            .accessibilityIdentifier("journal.attachment.remove-confirm")
                        }
                    }
                }
            }
            .saveError($error)
    }
}
