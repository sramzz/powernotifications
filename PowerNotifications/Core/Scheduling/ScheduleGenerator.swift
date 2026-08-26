import Foundation

struct PromptSnapshot: Equatable, Sendable {
    let id: UUID
    let text: String
}

struct ScheduleConfiguration: Equatable, Sendable {
    let count: Int
    let wakeMinute: Int
    let bedtimeMinute: Int

    var activeWindowMinutes: Int {
        guard (0..<1_440).contains(wakeMinute),
              (0..<1_440).contains(bedtimeMinute),
              wakeMinute != bedtimeMinute else {
            return 0
        }
        return (bedtimeMinute - wakeMinute + 1_440) % 1_440
    }

    var maximumCount: Int {
        min(20, activeWindowMinutes)
    }
}

struct ScheduledSlot: Equatable, Identifiable, Sendable {
    let id: String
    let minuteOffset: Int
    let minuteOfDay: Int
    let promptID: UUID
    let promptText: String
    let configuration: ScheduleConfiguration

    init(
        id: String = UUID().uuidString,
        minuteOffset: Int,
        minuteOfDay: Int,
        promptID: UUID,
        promptText: String,
        configuration: ScheduleConfiguration
    ) {
        self.id = id
        self.minuteOffset = minuteOffset
        self.minuteOfDay = minuteOfDay
        self.promptID = promptID
        self.promptText = promptText
        self.configuration = configuration
    }
}

enum ScheduleGenerationError: Error, Equatable {
    case noPrompts
    case equalWakeAndBedtime
    case invalidTime
    case invalidCount(maximum: Int)
}

enum ScheduleGenerator {
    static func maximumCount(wakeMinute: Int, bedtimeMinute: Int) -> Int {
        ScheduleConfiguration(
            count: 1,
            wakeMinute: wakeMinute,
            bedtimeMinute: bedtimeMinute
        ).maximumCount
    }

    static func generate<R: RandomNumberGenerator>(
        prompts: [PromptSnapshot],
        count: Int,
        wakeMinute: Int,
        bedtimeMinute: Int,
        using random: inout R
    ) throws -> [ScheduledSlot] {
        try generate(
            prompts: prompts,
            configuration: ScheduleConfiguration(
                count: count,
                wakeMinute: wakeMinute,
                bedtimeMinute: bedtimeMinute
            ),
            using: &random
        )
    }

    static func generate<R: RandomNumberGenerator>(
        prompts: [PromptSnapshot],
        configuration: ScheduleConfiguration,
        using random: inout R
    ) throws -> [ScheduledSlot] {
        guard !prompts.isEmpty else { throw ScheduleGenerationError.noPrompts }
        guard (0..<1_440).contains(configuration.wakeMinute),
              (0..<1_440).contains(configuration.bedtimeMinute) else {
            throw ScheduleGenerationError.invalidTime
        }
        guard configuration.wakeMinute != configuration.bedtimeMinute else {
            throw ScheduleGenerationError.equalWakeAndBedtime
        }

        let duration = configuration.activeWindowMinutes
        let maximum = configuration.maximumCount
        guard (1...maximum).contains(configuration.count) else {
            throw ScheduleGenerationError.invalidCount(maximum: maximum)
        }

        var promptAssignments: [PromptSnapshot] = []
        while promptAssignments.count < configuration.count {
            var cycle = prompts
            cycle.shuffle(using: &random)
            promptAssignments.append(
                contentsOf: cycle.prefix(configuration.count - promptAssignments.count)
            )
        }

        return (0..<configuration.count).map { index in
            let segmentStart = index * duration / configuration.count
            let segmentEnd = (index + 1) * duration / configuration.count
            let minuteOffset = Int.random(in: segmentStart..<segmentEnd, using: &random)
            let prompt = promptAssignments[index]

            return ScheduledSlot(
                minuteOffset: minuteOffset,
                minuteOfDay: (configuration.wakeMinute + minuteOffset) % 1_440,
                promptID: prompt.id,
                promptText: prompt.text,
                configuration: configuration
            )
        }
    }
}
