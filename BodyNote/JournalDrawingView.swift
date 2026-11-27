import SwiftUI
import PencilKit
import BodyNoteCore

struct JournalDrawingView: View {
    let draftID: UUID
    let onAttach: (Data) throws -> Void
    @EnvironmentObject private var store: JournalStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase
    @StateObject private var sketch = JournalSketch()
    @State private var tool = SketchTool.pen

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if sketch.ready {
                Picker("그리기 도구", selection: $tool) {
                    ForEach(SketchTool.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .disabled(sketch.attached)
                SketchPaper(canvas: sketch.canvas, tool: tool)
                    .aspectRatio(JournalSketch.page.width / JournalSketch.page.height, contentMode: .fit)
                    .overlay { Rectangle().strokeBorder(.secondary.opacity(0.35)).allowsHitTesting(false) }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(!sketch.attached)
            } else if sketch.problem == nil {
                ProgressView("그림 여는 중")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            if let problem = sketch.problem {
                Text(problem).font(.footnote).foregroundStyle(.red)
                Button("다시 시도") {
                    if sketch.ready { sketch.saveChanges() }
                    else { sketch.load(from: store.media, draftID: draftID) }
                }
            }
        }
        .padding()
        .navigationTitle("그림 그리기")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("닫기") {
                    if sketch.saveChanges() { dismiss() }
                }
                .accessibilityIdentifier("journal.drawing.close")
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(sketch.attached ? "완료" : "일지에 첨부") {
                    if sketch.attach(using: onAttach) { dismiss() }
                }
                .disabled(!sketch.hasInk)
                .accessibilityIdentifier("journal.drawing.attach")
            }
        }
        .interactiveDismissDisabled(sketch.ready && sketch.problem != nil)
        .onAppear { sketch.load(from: store.media, draftID: draftID) }
        .onChange(of: phase) { _, phase in
            if phase != .active { sketch.saveChanges() }
        }
        .onDisappear { sketch.saveChanges() }
    }
}

private enum SketchTool: String, CaseIterable {
    case pen = "펜", marker = "형광펜", eraser = "지우개"

    var pencilTool: any PKTool {
        switch self {
        case .pen: return PKInkingTool(.pen, color: .black, width: 4)
        case .marker: return PKInkingTool(.marker, color: .systemOrange, width: 14)
        case .eraser: return PKEraserTool(.vector)
        }
    }
}

@MainActor
private final class JournalSketch: NSObject, ObservableObject, PKCanvasViewDelegate {
    // Stroke coordinates and the exported page stay the same during rotation and Split View.
    static let page = CGRect(x: 0, y: 0, width: 1024, height: 768)
    let canvas = PKCanvasView(frame: JournalSketch.page)
    @Published private(set) var ready = false
    @Published private(set) var hasInk = false
    @Published private(set) var attached = false
    @Published private(set) var problem: String?
    private var media: JournalAttachmentStore?
    private var draftID: UUID?
    private var savedData: Data?

    func load(from media: JournalAttachmentStore, draftID: UUID) {
        guard !ready else { return }
        do {
            let data = try media.drawingDraft(for: draftID)
            canvas.drawing = try data.map { try PKDrawing(data: $0) } ?? PKDrawing()
            self.media = media
            self.draftID = draftID
            savedData = data
            hasInk = !canvas.drawing.bounds.isEmpty
            canvas.delegate = self
            ready = true
            problem = nil
        } catch {
            problem = "그림을 열지 못했어요. \(error.localizedDescription)"
        }
    }

    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        hasInk = !canvasView.drawing.bounds.isEmpty
        saveChanges()
    }

    @discardableResult
    func saveChanges() -> Bool {
        guard ready, let media, let draftID else { return true }
        let drawing = canvas.drawing
        let data = attached || drawing.bounds.isEmpty ? nil : drawing.dataRepresentation()
        do {
            if data != savedData {
                try media.saveDrawingDraft(data, for: draftID)
                savedData = data
            }
            problem = nil
            return true
        } catch {
            problem = "그림을 보관하지 못했어요. \(error.localizedDescription)"
            return false
        }
    }

    func attach(using onAttach: (Data) throws -> Void) -> Bool {
        let drawing = canvas.drawing
        guard ready, !drawing.bounds.isEmpty else { return false }
        if !attached {
            let format = UIGraphicsImageRendererFormat()
            format.scale = 2
            format.opaque = true
            let page = Self.page
            let ink = drawing.image(from: page, scale: format.scale)
            let image = UIGraphicsImageRenderer(bounds: page, format: format).pngData { context in
                context.cgContext.setFillColor(UIColor.white.cgColor)
                context.cgContext.fill(page)
                ink.draw(in: page)
            }
            do {
                try onAttach(image)
                attached = true
            } catch {
                problem = "일지에 그림을 첨부하지 못했어요. \(error.localizedDescription)"
                return false
            }
        }
        return saveChanges()
    }
}

private struct SketchPaper: UIViewRepresentable {
    let canvas: PKCanvasView
    let tool: SketchTool

    func makeUIView(context: Context) -> PaperView {
        let paper = PaperView(frame: .zero)
        canvas.contentSize = JournalSketch.page.size
        canvas.contentInsetAdjustmentBehavior = .never
        canvas.isScrollEnabled = false
        canvas.backgroundColor = .white
        canvas.overrideUserInterfaceStyle = .light
        canvas.drawingPolicy = .anyInput
        canvas.isAccessibilityElement = true
        canvas.accessibilityLabel = "그림 종이"
        canvas.accessibilityIdentifier = "journal.drawing.canvas"
        canvas.accessibilityTraits.insert(.allowsDirectInteraction)
        paper.addSubview(canvas)
        return paper
    }

    func updateUIView(_ paper: PaperView, context: Context) {
        if paper.selectedTool != tool {
            paper.selectedTool = tool
            canvas.tool = tool.pencilTool
        }
    }

    final class PaperView: UIView {
        var selectedTool: SketchTool?

        override func layoutSubviews() {
            super.layoutSubviews()
            guard bounds.width > 0, bounds.height > 0, let canvas = subviews.first as? PKCanvasView else { return }
            let page = JournalSketch.page
            let scale = min(bounds.width / page.width, bounds.height / page.height)
            canvas.transform = CGAffineTransform(scaleX: scale, y: scale)
            canvas.center = CGPoint(x: bounds.midX, y: bounds.midY)
        }
    }
}
