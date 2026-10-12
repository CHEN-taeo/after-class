import Foundation

enum PetMood: String, Codable, CaseIterable { case happy, sleepy, curious, delighted, calm }
enum PetAction: String, Codable { case idle, bounce, wave, celebrate, rest }

struct Course: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var room: String
    /// Monday = 1, Sunday = 7. End is exclusive.
    var weekday: Int
    var startMinute: Int
    var endMinute: Int
    var weeks: [Int] = Array(1...20)
    var colorIndex: Int = 0

    var timeLabel: String { "\(Self.clock(startMinute)) – \(Self.clock(endMinute))" }
    static func clock(_ minute: Int) -> String { String(format: "%02d:%02d", minute / 60, minute % 60) }
    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && title.count <= 60 && room.count <= 80
        && (1...7).contains(weekday) && (0..<1440).contains(startMinute)
        && endMinute > startMinute && endMinute <= 1440 && !weeks.isEmpty
        && weeks.allSatisfy { (1...30).contains($0) }
    }
}

struct ChatMessage: Codable, Identifiable, Equatable {
    enum Role: String, Codable { case user, assistant }
    var id = UUID()
    var role: Role
    var text: String
    var date = Date()
    var isOffline = false
}

struct AIConfiguration: Codable, Equatable {
    var baseURL = "https://api.openai.com/v1"
    var model = ""
    var enabled = false
}

struct AppSnapshot: Codable {
    var schemaVersion = 1
    var termStart: Date
    var courses: [Course]
    var messages: [ChatMessage] = []
    var memory = ""
    var ai = AIConfiguration()
    var isDemo = true

    static func demo(now: Date = Date()) -> AppSnapshot {
        AppSnapshot(termStart: ScheduleEngine.monday(containing: now), courses: [
            Course(title: "机械原理", room: "教学楼 A · 302", weekday: 1, startMinute: 480, endMinute: 575, colorIndex: 0),
            Course(title: "大学英语", room: "教学楼 B · 208", weekday: 1, startMinute: 610, endMinute: 705, colorIndex: 1),
            Course(title: "高等数学", room: "教学楼 A · 201", weekday: 2, startMinute: 510, endMinute: 605, colorIndex: 2),
            Course(title: "机械原理", room: "教学楼 A · 302", weekday: 2, startMinute: 630, endMinute: 725, colorIndex: 0),
            Course(title: "体育", room: "西区操场", weekday: 2, startMinute: 870, endMinute: 960, colorIndex: 1),
            Course(title: "工程制图", room: "实验楼 · 405", weekday: 3, startMinute: 540, endMinute: 660, colorIndex: 3),
            Course(title: "大学英语", room: "教学楼 B · 208", weekday: 4, startMinute: 600, endMinute: 695, colorIndex: 1),
            Course(title: "机器人实验", room: "实验楼 · 101", weekday: 5, startMinute: 840, endMinute: 960, colorIndex: 0)
        ])
    }
}

enum SchedulePhase: Equatable {
    case noClasses, before(Course), inClass(Course), between(Course), finished
}

enum ScheduleEngine {
    static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "zh_CN")
        c.timeZone = .current
        c.firstWeekday = 2
        return c
    }
    static func monday(containing date: Date, calendar: Calendar = ScheduleEngine.calendar) -> Date {
        let day = calendar.startOfDay(for: date)
        let offset = (calendar.component(.weekday, from: day) + 5) % 7
        return calendar.date(byAdding: .day, value: -offset, to: day)!
    }
    static func week(on date: Date, termStart: Date, calendar: Calendar = ScheduleEngine.calendar) -> Int {
        let days = calendar.dateComponents([.day], from: monday(containing: termStart, calendar: calendar),
                                          to: calendar.startOfDay(for: date)).day ?? 0
        return Int(floor(Double(days) / 7)) + 1
    }
    static func courses(on date: Date, snapshot: AppSnapshot, calendar: Calendar = ScheduleEngine.calendar) -> [Course] {
        let weekday = (calendar.component(.weekday, from: date) + 5) % 7 + 1
        let week = week(on: date, termStart: snapshot.termStart, calendar: calendar)
        return snapshot.courses.filter { $0.isValid && $0.weekday == weekday && $0.weeks.contains(week) }
            .sorted { $0.startMinute == $1.startMinute ? $0.title < $1.title : $0.startMinute < $1.startMinute }
    }
    static func phase(at date: Date, snapshot: AppSnapshot, calendar: Calendar = ScheduleEngine.calendar) -> SchedulePhase {
        let courses = courses(on: date, snapshot: snapshot, calendar: calendar)
        guard let first = courses.first else { return .noClasses }
        let minute = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        if let current = courses.first(where: { $0.startMinute <= minute && minute < $0.endMinute }) { return .inClass(current) }
        if minute < first.startMinute { return .before(first) }
        if let next = courses.first(where: { $0.startMinute > minute }) { return .between(next) }
        return .finished
    }
    static func conflicts(_ course: Course, among courses: [Course]) -> Bool {
        courses.contains {
            $0.id != course.id && $0.weekday == course.weekday
            && !Set($0.weeks).isDisjoint(with: course.weeks)
            && course.startMinute < $0.endMinute && $0.startMinute < course.endMinute
        }
    }
}

struct CompanionReply: Codable {
    let text: String
    let mood: PetMood
    let action: PetAction

    static func decode(_ content: String) throws -> CompanionReply {
        var cleaned = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("```") {
            cleaned = cleaned.components(separatedBy: "\n").dropFirst().dropLast().joined(separator: "\n")
        }
        let reply = try JSONDecoder().decode(Self.self, from: Data(cleaned.utf8))
        guard !reply.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, reply.text.count <= 600 else {
            throw AIError.invalidReply
        }
        return reply
    }
}
