import SwiftUI
import BodyNoteCore

struct WeeklyTrackingView: View {
    @EnvironmentObject private var store: JournalStore

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { clock in
            let week = store.book.tracking(at: clock.date)
            VStack(alignment: .leading, spacing: 10) {
                Text("최근 7일").font(.headline)
                Text("운동 \(week.activeDays)일  ·  \(week.sessions)회  ·  \(week.sets)세트")
                    .font(.title3.bold()).foregroundStyle(TrackColor.green)
                HStack(spacing: 4) {
                    ForEach(week.days) { day in
                        NavigationLink {
                            List {
                                let records = store.book.newestFirst.filter { $0.day == day.day }
                                if records.isEmpty { Text("이날은 기록이 없어요.") }
                                ForEach(records) { entry in
                                    NavigationLink { EntryDetail(id: entry.id) } label: { EntryRow(entry: entry) }
                                }
                            }.navigationTitle(day.day.shortLabel)
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: day.sessions > 0 ? "checkmark.circle.fill" : day.rested ? "moon.fill" : "circle")
                                Text("\(day.day.day)일").font(.caption2)
                            }.frame(maxWidth: .infinity, minHeight: 44)
                        }.accessibilityLabel("\(day.day.shortLabel), 운동 \(day.sessions)회\(day.rested ? ", 휴식 기록" : "")")
                    }
                }
                Text("그전 7일은 운동 \(week.previousActiveDays)일").font(.caption).foregroundStyle(.secondary)
                ForEach(week.cues, id: \.kind.rawValue) { cue in
                    NavigationLink {
                        EntryDetail(id: cue.entryID)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Label(cue.title, systemImage: cue.kind == .rest ? "moon" : "cross.case").font(.subheadline.bold())
                            Text(cue.detail).font(.footnote)
                            Text("\(cue.day.shortLabel) 기록 보기 ›").font(.caption)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }.padding().background(.background, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}
