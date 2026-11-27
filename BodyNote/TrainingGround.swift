import SwiftUI
import BodyNoteCore

enum TrackColor {
    static let green = Color(red: 15/255, green: 77/255, blue: 64/255)
    static let cream = Color(red: 1, green: 247/255, blue: 235/255)
    static let orange = Color(red: 1, green: 136/255, blue: 61/255)
    static let gray = Color(red: 214/255, green: 217/255, blue: 205/255)
}

private extension TrainingSport {
    @ViewBuilder var kitIcon: some View {
        switch self {
        case .running: Image(systemName: "shoe.2")
        case .fieldHockey: Text("🏑")
        case .weightTraining: Image(systemName: "dumbbell.fill")
        case .basic: Image(systemName: "cross.fill")
        case .soccer, .basketball: EmptyView()
        }
    }
}

enum TrainingMotion: String, CaseIterable {
    case idle, stretch, ready, run, levelUp

    var title: String {
        switch self {
        case .idle: return "대기"
        case .stretch: return "스트레칭"
        case .ready: return "준비"
        case .run: return "달리기"
        case .levelUp: return "성장"
        }
    }
}

extension JournalStore.Receipt {
    var rewardMotion: TrainingMotion? {
        if didLevelUp { return .levelUp }
        return addedXP ? .run : nil
    }
}

private struct MotionBeat: Equatable {
    let seconds: Double
    var x: CGFloat = 0
    var y: CGFloat = 0
    var scaleX: CGFloat = 1
    var scaleY: CGFloat = 1
    var degrees: Double = 0
    var alternateFrame = false
}

private extension TrainingMotion {
    // Each beat describes the next position. Offsets are fractions of the player's size.
    var beats: [MotionBeat] {
        switch self {
        case .idle:
            return [.init(seconds: 1.1), .init(seconds: 1.1, scaleX: 0.985, scaleY: 1.035)]
        case .stretch:
            return [.init(seconds: 0.9), .init(seconds: 0.9, x: 0.03, scaleX: 1.035, scaleY: 0.935, degrees: 4)]
        case .ready:
            return [.init(seconds: 0.54), .init(seconds: 0.66, x: 0.02, scaleX: 1.05, scaleY: 0.89, degrees: 3)]
        case .run:
            return [
                .init(seconds: 0.175),
                .init(seconds: 0.125, x: 0.02, y: -0.08, degrees: -2),
                .init(seconds: 0.2, x: -0.01, scaleX: 1.02, scaleY: 0.96, degrees: 2, alternateFrame: true)
            ]
        case .levelUp:
            return [
                .init(seconds: 0.30, alternateFrame: true),
                .init(seconds: 0.225, scaleX: 1.07, scaleY: 0.88, alternateFrame: true),
                .init(seconds: 0.3625, y: -0.22, scaleX: 0.98, scaleY: 1.03, degrees: -3),
                .init(seconds: 0.3125, y: -0.02),
                .init(seconds: 0.05, scaleX: 1.07, scaleY: 0.88, alternateFrame: true)
            ]
        }
    }
}

struct AthleteImage: View {
    let animal: Animal
    let sport: TrainingSport
    var motion: TrainingMotion = .idle
    var alternateFrame = false

    var body: some View {
        if motion == .idle || (motion == .levelUp && alternateFrame) {
            Image("\(animal.rawValue)-\(sport.rawValue)")
                .resizable().scaledToFit().accessibilityHidden(true)
        } else {
            // Each pose sheet has four sport rows and four animal columns.
            let column = Animal.allCases.firstIndex(of: animal) ?? 0
            let row = TrainingSport.available.firstIndex(of: sport) ?? 0
            let sheet = motion == .run && alternateFrame ? "Motion-runContact" : "Motion-\(motion.rawValue)"
            Color.clear.aspectRatio(248.0 / 280.0, contentMode: .fit)
                .overlay {
                    GeometryReader { frame in
                        Image(sheet).resizable()
                            .frame(width: frame.size.width * 4, height: frame.size.height * 4)
                            .offset(x: -frame.size.width * CGFloat(column), y: -frame.size.height * CGFloat(row))
                    }
                    .clipped()
                }
                .accessibilityHidden(true)
        }
    }
}

struct AthletePlayer: View {
    let athlete: Athlete
    let motion: TrainingMotion
    let isPlaying: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion || !isPlaying {
            AthleteImage(animal: athlete.animal, sport: athlete.sport, motion: motion)
        } else {
            GeometryReader { proxy in
                PhaseAnimator(motion.beats) { beat in
                    AthleteImage(animal: athlete.animal, sport: athlete.sport,
                                 motion: motion, alternateFrame: beat.alternateFrame)
                        .contentTransition(.identity)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .scaleEffect(x: beat.scaleX, y: beat.scaleY, anchor: .bottom)
                        .rotationEffect(.degrees(beat.degrees), anchor: .bottom)
                        .offset(x: beat.x * proxy.size.width, y: beat.y * proxy.size.height)
                } animation: { beat in
                    .easeInOut(duration: beat.seconds)
                }
            }
            .id(motion)
        }
    }
}

struct TrainingScene: View {
    @EnvironmentObject private var store: JournalStore
    let book: Notebook
    let previewMotion: TrainingMotion?
    @State private var selectionEvent: UUID?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(book: Notebook, previewMotion: TrainingMotion? = nil) {
        self.book = book
        self.previewMotion = previewMotion
    }

    var body: some View {
        let athlete = previewMotion == nil ? book.fieldAthlete : book.athlete
        let resting = book.entries.contains { $0.day == JournalDay() && $0.kind == .rest }
        let motion = previewMotion ?? currentMotion(resting: resting)
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            ZStack(alignment: .topLeading) {
                Image("TrainingTrack")
                    .resizable().frame(width: w, height: h)
                AthletePlayer(athlete: athlete, motion: motion,
                              isPlaying: previewMotion != nil || motion == .levelUp || motion == .run || motion == .ready)
                    .frame(width: w * 0.40, height: h * 0.58)
                    .position(x: w * 0.34, y: h * 0.55)
                ForEach(0..<min(book.activeDayCount, 5), id: \.self) { index in
                    Image(systemName: "checkmark.seal.fill")
                        .resizable().scaledToFit()
                        .foregroundStyle(TrackColor.green)
                        .frame(width: w * 0.044, height: h * 0.064)
                        .position(x: w * (0.671 + CGFloat(index) * 0.0565), y: h * 0.472)
                }
                if book.activeDayCount >= 3 {
                    Text(book.hasMatArea ? "매트 구역 개방" : "콘 코스 개방")
                        .font(.caption2.bold()).padding(.horizontal, 7).padding(.vertical, 3)
                        .foregroundStyle(.white).background(TrackColor.green, in: Capsule())
                        .position(x: w * 0.81, y: h * 0.91)
                }
                if previewMotion == nil && store.receipt?.didLevelUp == true && motion == .levelUp {
                    Label("레벨 업!", systemImage: "sparkles").font(.caption.bold()).padding(5)
                        .background(TrackColor.cream, in: Capsule())
                        .position(x: w * 0.34, y: h * 0.19)
                }
                if resting {
                    Label("휴식일", systemImage: "moon.fill")
                        .font(.caption.bold()).padding(6)
                        .background(TrackColor.cream, in: Capsule()).padding(8)
                }
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: athlete)
        }
        .aspectRatio(542.0 / 403.0, contentMode: .fit)
        .overlay(alignment: .bottomLeading) {
            if previewMotion == nil && book.entries.contains(where: { $0.kind != .rest }) {
                Text("최근 훈련 · \(athlete.sport.title) 스킨")
                    .font(.caption2.bold()).padding(.horizontal, 8).padding(.vertical, 4)
                    .foregroundStyle(TrackColor.green).background(TrackColor.cream, in: Capsule()).padding(8)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(athlete.sport.title) 복장의 \(athlete.animal.title), \(motion.title). 훈련 도장 \(min(book.activeDayCount, 5))개.")
        .onChange(of: athlete) { _, _ in selectionEvent = UUID() }
        .task(id: selectionEvent) {
            guard selectionEvent != nil else { return }
            try? await Task.sleep(for: .milliseconds(850))
            if !Task.isCancelled { selectionEvent = nil }
        }
    }

    private func currentMotion(resting: Bool) -> TrainingMotion {
        if let reward = store.receipt?.rewardMotion { return reward }
        if selectionEvent != nil { return .ready }
        return resting ? .idle : .stretch
    }
}

struct TrainingProgress: View {
    let book: Notebook

    var body: some View {
        HStack(spacing: 12) {
            Image("TrackBadge").resizable().scaledToFit().frame(width: 48)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                ViewThatFits(in: .horizontal) {
                    HStack {
                        levelText.fixedSize()
                        Spacer()
                        nextText.fixedSize()
                    }
                    VStack(alignment: .leading) { levelText; nextText }
                }
                ProgressView(value: Double(book.levelXP), total: Double(Notebook.xpPerLevel))
                    .tint(TrackColor.green)
                    .accessibilityLabel("레벨 진행률")
            }
        }
        .padding(.vertical, 4)
    }

    private var levelText: some View { Text("Lv. \(book.level) · \(book.xp) XP").font(.headline.bold()) }
    private var nextText: some View { Text("다음 레벨까지 \(book.remainingXP) XP").font(.caption).foregroundStyle(.secondary) }
}

struct KitChoice: View {
    let animal: Animal
    let sport: TrainingSport
    let title: String
    let selected: Bool
    var showsSportIcon = false
    let choose: () -> Void

    var body: some View {
        Button(action: choose) {
            VStack(spacing: 5) {
                AthleteImage(animal: animal, sport: sport)
                    .padding(3)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(0.97, contentMode: .fit)
                    .background(TrackColor.cream, in: RoundedRectangle(cornerRadius: 13))
                    .overlay {
                        RoundedRectangle(cornerRadius: 13)
                            .strokeBorder(selected ? TrackColor.green : .black.opacity(0.10), lineWidth: selected ? 2.5 : 1)
                    }
                    .overlay(alignment: .topTrailing) {
                        if selected {
                            Image(systemName: "checkmark.circle.fill")
                                .symbolRenderingMode(.palette).foregroundStyle(.white, TrackColor.green)
                                .offset(x: 2, y: -3)
                        }
                    }
                HStack(spacing: 3) {
                    if showsSportIcon { sport.kitIcon.accessibilityHidden(true) }
                    Text(title)
                }
                .font(.caption.bold())
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
