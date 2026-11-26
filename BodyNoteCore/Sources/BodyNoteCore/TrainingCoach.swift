import Foundation

public enum CoachTopic: String, Codable {
    case review, recovery, focus, confidence, discomfort, support, safety, conversation
}

public struct CoachReflectionRequest {
    public let question: String
    public let topic: CoachTopic
    public let animal: Animal
    public let previousQuestion: String?
    public let previousAnswer: String?
}

public protocol CoachTopicChoosing {
    func topic(for question: String, previous: CoachTopic?) async -> CoachTopic?
    func reflection(for request: CoachReflectionRequest) async -> String?
}

public extension CoachTopicChoosing {
    func reflection(for request: CoachReflectionRequest) async -> String? { nil }
}

public struct CoachTurn: Identifiable, Codable, Equatable {
    public let id: UUID
    public let athlete: Athlete
    public let question: String
    public let answer: String
    public let topic: CoachTopic
    public let usedModel: Bool
    private var didGenerateReflection: Bool?
    public var generatedReflection: Bool { didGenerateReflection == true }

    init(id: UUID, athlete: Athlete, question: String, answer: String, topic: CoachTopic,
         usedModel: Bool, generatedReflection: Bool = false) {
        self.id = id
        self.athlete = athlete
        self.question = question
        self.answer = answer
        self.topic = topic
        self.usedModel = usedModel
        didGenerateReflection = generatedReflection ? true : nil
    }
}

public enum TrainingCoach {
    public static func reply(to question: String, athlete: Athlete, week: TrackingWeek,
                             previous: CoachTopic?, provider: (any CoachTopicChoosing)? = nil,
                             previousTurn: CoachTurn? = nil) async -> CoachTurn {
        let text = question.lowercased().filter { !$0.isWhitespace }
        func mentions(_ words: [String]) -> Bool { words.contains { text.contains($0) } }
        let topic: CoachTopic
        var usedModel = false
        if mentions(["자해", "자살", "죽고싶", "죽을래", "목숨을끊", "killmyself", "suicid", "wanttodie"]) {
            topic = .safety
        } else if mentions(["우울증", "공황", "불안장애", "정신과", "정신건강", "섭식장애", "심리치료", "depression", "panicattack", "eatingdisorder"]) {
            topic = .support
        } else if mentions(["통증", "아파", "아프", "다쳤", "부상", "붓", "부었", "진단", "골절", "치료", "처방", "진통제", "pain", "injur", "medication"]) {
            topic = .discomfort
        } else if mentions(["얼마나운동", "몇세트", "몇회", "며칠운동", "운동량", "기록요약", "기록보여", "운동을돌아"]) {
            topic = .review
        } else if mentions(["휴식", "쉬어", "쉴까", "회복", "피곤", "rest"]) {
            topic = .recovery
        } else if let selected = await provider?.topic(for: question, previous: previous) {
            topic = selected
            usedModel = true
        } else if mentions(["휴식", "쉬", "회복", "피곤", "rest", "지쳤"]) { topic = .recovery }
        else if mentions(["긴장", "떨", "집중", "시합", "불안", "경기", "focus"]) { topic = .focus }
        else if mentions(["자신", "실수", "속상", "좌절", "의욕", "부담", "못했", "비교", "동기"]) { topic = .confidence }
        else if mentions(["기록", "요약", "세트", "운동량", "지난주", "이번주", "얼마", "운동을돌아"]) { topic = .review }
        else if previous == .focus || previous == .confidence { topic = previous ?? .conversation }
        else { topic = .conversation }

        let isReflection: (CoachTopic) -> Bool = { [.focus, .confidence, .conversation].contains($0) }
        if isReflection(topic), let provider {
            let prior = previousTurn.flatMap { $0.athlete.animal == athlete.animal && isReflection($0.topic) ? $0 : nil }
            let request = CoachReflectionRequest(question: String(question.prefix(1200)), topic: topic, animal: athlete.animal,
                                                 previousQuestion: prior.map { String($0.question.prefix(500)) },
                                                 previousAnswer: prior.map { String($0.answer.prefix(500)) })
            if let text = await provider.reflection(for: request)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !text.isEmpty, text.count <= 350 {
                return CoachTurn(id: UUID(), athlete: athlete, question: question, answer: text, topic: topic,
                                 usedModel: true, generatedReflection: true)
            }
        }

        let answer: String
        switch topic {
        case .review:
            answer = week.sessions == 0 ? "최근 7일에 확정한 운동이 아직 없어. 첫 운동을 남기면 운동한 날과 세트를 같이 돌아볼 수 있어."
                : "최근 7일은 \(week.activeDays)일에 걸쳐 \(week.sessions)회 운동했고 \(week.sets)세트를 기록했어. 그전 7일은 \(week.previousActiveDays)일이었어. 어떤 운동을 다시 보고 싶어?"
        case .recovery:
            answer = week.cues.first.map { "\($0.title). \($0.detail)" } ?? "오늘 몸은 어때? 쉬기로 했다면 일지에서 ‘휴식’을 골라 이유를 한 줄 남겨 봐. 다음 운동 전에 다시 살펴볼 수 있어."
        case .focus:
            answer = previous == .focus ? "그 순간에 네가 직접 바꿀 수 있는 행동은 뭐야? 경기 시작 전에 떠올릴 짧은 말 하나로 정해 보면 어때?"
                : "경기를 앞두고 긴장되는구나. 결과 말고 첫 동작에만 집중해 보자. 시작하는 순간에 해낼 수 있는 행동 한 가지가 뭐야?"
        case .confidence:
            answer = previous == .confidence ? "그 장면에서 다음에도 해 보고 싶은 행동을 한 줄로 적어 볼까? 네가 정한 그 행동을 다음 훈련의 목표로 삼을 수 있어."
                : "마음에 걸리는 장면이 있었구나. 오늘 결과와 별개로 네가 끝까지 시도한 일 한 가지를 들려줄래?"
        case .discomfort: answer = "어떤 동작에서 불편했는지 일지에 남겨 줘. 아픈 동작은 멈추고, 통증이 심해지거나 체중을 싣기 어렵다면 의료진에게 진료를 받아."
        case .support: answer = "그 이야기를 들려줘서 고마워. 마음의 어려움이 계속되거나 일상에 영향을 준다면 믿는 사람이나 정신건강 전문가에게 이야기해 봐. 오늘 연락할 수 있는 사람이 있어?"
        case .safety: answer = "지금은 네 안전이 먼저야. 당장 다칠 위험이 있다면 현지 응급 서비스에 연락하고, 가까운 사람에게 곁에 있어 달라고 해 줘."
        case .conversation: answer = "오늘 운동에서 기억에 남는 순간이 뭐야? 운동 기록을 같이 보거나, 긴장됐던 장면과 다음에 해 보고 싶은 행동을 이야기해도 좋아."
        }
        return CoachTurn(id: UUID(), athlete: athlete, question: question, answer: answer, topic: topic, usedModel: usedModel)
    }
}
