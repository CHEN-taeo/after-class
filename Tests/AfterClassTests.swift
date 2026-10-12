import XCTest
@testable import AfterClass

final class AfterClassTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        c.firstWeekday = 2
        return c
    }
    private func date(_ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }
    private var sample: AppSnapshot {
        AppSnapshot(termStart: date(5), courses: [Course(title: "机械原理", room: "A302", weekday: 1, startMinute: 480, endMinute: 575, weeks: [1, 3])])
    }
    func testWeekBeforeTermIsZero() {
        XCTAssertEqual(ScheduleEngine.week(on: date(4), termStart: date(5), calendar: calendar), 0)
    }
    func testTermDateNormalizesToMonday() {
        XCTAssertEqual(ScheduleEngine.week(on: date(5), termStart: date(7), calendar: calendar), 1)
        XCTAssertEqual(ScheduleEngine.week(on: date(12), termStart: date(7), calendar: calendar), 2)
    }
    func testOddWeeksAndWeekday() {
        XCTAssertEqual(ScheduleEngine.courses(on: date(5), snapshot: sample, calendar: calendar).count, 1)
        XCTAssertTrue(ScheduleEngine.courses(on: date(12), snapshot: sample, calendar: calendar).isEmpty)
        XCTAssertEqual(ScheduleEngine.courses(on: date(19), snapshot: sample, calendar: calendar).count, 1)
        XCTAssertTrue(ScheduleEngine.courses(on: date(6), snapshot: sample, calendar: calendar).isEmpty)
    }
    func testExactCourseBoundaries() {
        XCTAssertEqual(ScheduleEngine.phase(at: date(5, 7, 59), snapshot: sample, calendar: calendar), .before(sample.courses[0]))
        XCTAssertEqual(ScheduleEngine.phase(at: date(5, 8), snapshot: sample, calendar: calendar), .inClass(sample.courses[0]))
        XCTAssertEqual(ScheduleEngine.phase(at: date(5, 9, 35), snapshot: sample, calendar: calendar), .finished)
    }
    func testSubjectCharacterMapping() {
        XCTAssertEqual(SubjectCharacterKind(courseTitle: "高等数学"), .compass)
        XCTAssertEqual(SubjectCharacterKind(courseTitle: "工程制图"), .fold)
        XCTAssertEqual(SubjectCharacterKind(courseTitle: "大学英语"), .comma)
        XCTAssertEqual(SubjectCharacterKind(courseTitle: "机械原理"), .cam)
        XCTAssertEqual(SubjectCharacterKind(courseTitle: "体育"), .spring)
        XCTAssertEqual(SubjectCharacterKind(courseTitle: "机器人实验"), .probe)
        XCTAssertEqual(SubjectCharacterKind(courseTitle: "艺术史"), .seed)
    }
    func testOverlapsRequireSameWeek() {
        var other = sample.courses[0]
        other.id = UUID()
        XCTAssertTrue(ScheduleEngine.conflicts(other, among: sample.courses))
        other.weeks = [2]
        XCTAssertFalse(ScheduleEngine.conflicts(other, among: sample.courses))
        other.weeks = [1]; other.startMinute = 575; other.endMinute = 650
        XCTAssertFalse(ScheduleEngine.conflicts(other, among: sample.courses))
    }
    func testInvalidCoursesAreRejected() {
        var course = sample.courses[0]
        course.endMinute = course.startMinute
        XCTAssertFalse(course.isValid)
        course.endMinute = 600; course.weeks = []
        XCTAssertFalse(course.isValid)
        course.weeks = [1]; course.title = "   "
        XCTAssertFalse(course.isValid)
    }
    func testEndpointNormalizationAndRoot() throws {
        XCTAssertEqual(try AIClient.endpoint(for: "https://example.com/v1/").absoluteString, "https://example.com/v1/chat/completions")
        XCTAssertEqual(try AIClient.endpoint(for: "https://example.com/").absoluteString, "https://example.com/chat/completions")
        XCTAssertEqual(try AIClient.endpoint(for: "https://example.com/v1/chat/completions").absoluteString, "https://example.com/v1/chat/completions")
    }
    func testUnsafeEndpointsRejected() {
        for endpoint in ["http://example.com/v1", "https://user:secret@example.com/v1", "https://example.com/?key=a", "nonsense"] {
            XCTAssertThrowsError(try AIClient.endpoint(for: endpoint))
        }
    }
    func testReplyContract() throws {
        let reply = try CompanionReply.decode(#"{"text":"我在这里。","mood":"calm","action":"idle"}"#)
        XCTAssertEqual(reply.mood, .calm)
        XCTAssertThrowsError(try CompanionReply.decode(#"{"text":"hi","mood":"unknown","action":"idle"}"#))
        XCTAssertThrowsError(try CompanionReply.decode(#"{"text":" ","mood":"happy","action":"idle"}"#))
    }
    func testSnapshotRoundTripExcludesKey() throws {
        var state = sample
        state.memory = "高数课后想休息一会儿"
        state.messages = [ChatMessage(role: .user, text: "你好")]
        let data = try JSONEncoder().encode(state)
        let restored = try JSONDecoder().decode(AppSnapshot.self, from: data)
        XCTAssertEqual(restored.courses, state.courses)
        XCTAssertEqual(restored.messages, state.messages)
        XCTAssertEqual(restored.memory, state.memory)
        XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("apiKey"))
    }
    func testTimetableArchiveValidation() throws {
        let archive = TimetableArchive(snapshot: sample)
        let decoded = try TimetableArchive.read(JSONEncoder().encode(archive))
        XCTAssertEqual(decoded.courses, sample.courses)
        var invalid = archive
        invalid.courses += invalid.courses
        XCTAssertThrowsError(try TimetableArchive.read(JSONEncoder().encode(invalid)))
        invalid = archive; invalid.semesterStart = "2026-02-31"
        XCTAssertThrowsError(try TimetableArchive.read(JSONEncoder().encode(invalid)))
        invalid = archive; invalid.version = 99
        XCTAssertThrowsError(try TimetableArchive.read(JSONEncoder().encode(invalid)))
    }
    @MainActor func testStorePersistsCoursesAndExplicitClear() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("state.json")
        let store = AppStore(fileURL: url)
        store.startOwnTimetable()
        store.upsert(sample.courses[0])
        let restored = AppStore(fileURL: url)
        XCTAssertFalse(restored.snapshot.isDemo)
        XCTAssertEqual(restored.snapshot.courses, sample.courses)
        store.delete(sample.courses[0])
        XCTAssertTrue(AppStore(fileURL: url).snapshot.courses.isEmpty)
    }
    @MainActor func testCorruptFileIsNotOverwritten() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("state.json")
        let original = Data("corrupt-data".utf8)
        try original.write(to: url)
        let store = AppStore(fileURL: url)
        store.startOwnTimetable()
        XCTAssertEqual(try Data(contentsOf: url), original)
        XCTAssertNotNil(store.error)
    }
    @MainActor func testRestSurvivesClockUpdatesAndOtherInteractions() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("state.json")
        let store = AppStore(fileURL: url)
        store.interact("rest")
        let restingBubble = store.bubble
        store.refreshGreeting(now: Date().addingTimeInterval(7200))
        store.interact("celebrate")
        XCTAssertTrue(store.isResting)
        XCTAssertEqual(store.action, .rest)
        XCTAssertEqual(store.bubble, restingBubble)
        XCTAssertEqual(store.celebration, 0)
        store.interact("rest")
        XCTAssertFalse(store.isResting)
        XCTAssertEqual(store.action, .idle)
    }

}
