import Foundation
import Testing
@testable import PowerNotifications

@Suite("ScheduleGenerator")
struct ScheduleGeneratorTests {
    @Test("Distributes same-day slots across distinct segments")
    func distributesSameDaySlots() throws {
        var random = SeededRandomNumberGenerator(seed: 1)
        let prompt = PromptSnapshot(id: UUID(), text: "Pause and breathe")

        let slots = try ScheduleGenerator.generate(
            prompts: [prompt],
            count: 3,
            wakeMinute: 8 * 60,
            bedtimeMinute: 10 * 60,
            using: &random
        )

        #expect((480..<520).contains(slots[0].minuteOfDay))
        #expect((520..<560).contains(slots[1].minuteOfDay))
        #expect((560..<600).contains(slots[2].minuteOfDay))
        #expect(Set(slots.map(\.minuteOfDay)).count == 3)
    }

    @Test("Orders an overnight window from wake time through bedtime")
    func supportsOvernightWindows() throws {
        var random = SeededRandomNumberGenerator(seed: 2)
        let prompt = PromptSnapshot(id: UUID(), text: "Notice the moment")

        let slots = try ScheduleGenerator.generate(
            prompts: [prompt],
            count: 2,
            wakeMinute: 22 * 60,
            bedtimeMinute: 2 * 60,
            using: &random
        )

        #expect((0..<120).contains(slots[0].minuteOffset))
        #expect((120..<240).contains(slots[1].minuteOffset))
        #expect(slots.allSatisfy {
            $0.minuteOfDay == (1_320 + $0.minuteOffset) % 1_440
        })
    }

    @Test("Uses every prompt before repeating one")
    func exhaustsPromptsBeforeRepeating() throws {
        var random = SeededRandomNumberGenerator(seed: 3)
        let firstID = UUID()
        let secondID = UUID()

        let slots = try ScheduleGenerator.generate(
            prompts: [
                PromptSnapshot(id: firstID, text: "First"),
                PromptSnapshot(id: secondID, text: "Second")
            ],
            count: 5,
            wakeMinute: 8 * 60,
            bedtimeMinute: 9 * 60,
            using: &random
        )

        #expect(Set(slots[0...1].map(\.promptID)) == [firstID, secondID])
        #expect(Set(slots[2...3].map(\.promptID)) == [firstID, secondID])
    }

    @Test("Rejects equal wake and bedtime")
    func rejectsEqualWindowBounds() {
        var random = SeededRandomNumberGenerator(seed: 4)
        let prompt = PromptSnapshot(id: UUID(), text: "Hello")

        #expect(throws: ScheduleGenerationError.equalWakeAndBedtime) {
            try ScheduleGenerator.generate(
                prompts: [prompt],
                count: 1,
                wakeMinute: 480,
                bedtimeMinute: 480,
                using: &random
            )
        }
    }

    @Test("Caps the count at twenty and the active window length")
    func reportsDynamicMaximum() {
        #expect(ScheduleGenerator.maximumCount(wakeMinute: 480, bedtimeMinute: 500) == 20)
        #expect(ScheduleGenerator.maximumCount(wakeMinute: 480, bedtimeMinute: 485) == 5)
        #expect(ScheduleGenerator.maximumCount(wakeMinute: 480, bedtimeMinute: 480) == 0)
    }
}

private struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
}
