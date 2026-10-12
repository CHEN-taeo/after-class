import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @State private var tab = 0
    @State private var settings = false
    var body: some View {
        TabView(selection: $tab) {
            NavigationStack {
                TodayView(openChat: { tab = 2 })
                    .toolbar { ToolbarItem(placement: .topBarTrailing) {
                        Button { settings = true } label: { Image(systemName: "slider.horizontal.3") }
                            .accessibilityLabel("设置")
                    } }
            }.tabItem { Label("今天", systemImage: "sun.max") }.tag(0)
            NavigationStack { TimetableView() }
                .tabItem { Label("课表", systemImage: "rectangle.split.3x3") }.tag(1)
            NavigationStack { ChatView() }
                .tabItem { Label("说两句", systemImage: "bubble.left.and.bubble.right") }.tag(2)
        }
        .sheet(isPresented: $settings) { NavigationStack { SettingsView() } }
    }
}

struct TodayView: View {
    @EnvironmentObject private var store: AppStore
    let openChat: () -> Void

    private func featuredCourse(for phase: SchedulePhase, courses: [Course]) -> Course? {
        switch phase {
        case .before(let course), .inClass(let course), .between(let course): return course
        case .finished: return courses.last
        case .noClasses: return nil
        }
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let courses = ScheduleEngine.courses(on: context.date, snapshot: store.snapshot)
            let phase = ScheduleEngine.phase(at: context.date, snapshot: store.snapshot)
            let featured = featuredCourse(for: phase, courses: courses)
            let remaining = courses.filter { $0.id != featured?.id }
            let character = SubjectCharacterKind(courseTitle: featured?.title ?? "")
            let ended = courses.filter { $0.endMinute <= ScheduleEngine.minute(of: context.date) }.count
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 9) {
                        Text(context.date.formatted(.dateTime.month().day().weekday(.wide)))
                            .font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(Palette.muted)
                        HStack(alignment: .firstTextBaseline) {
                            Text("下课见").font(.system(size: 34, weight: .bold, design: .rounded))
                            Text("每节课都有自己的形状").font(.caption).foregroundStyle(Palette.muted)
                        }
                    }
                    if store.snapshot.isDemo {
                        Label("示例课表 · 时间变化不会修改课程", systemImage: "sparkles")
                            .font(.caption).foregroundStyle(Palette.muted)
                    }
                    MomentCard(phase: phase, now: context.date, featured: featured)
                    SubjectCharacterStage(course: featured, phase: phase, now: context.date)
                    SectionCaption(title: featured == nil ? "今天的安排" : "今天的其他安排",
                                   subtitle: courses.isEmpty ? "空白也很好" : "\(ended) / \(courses.count) 节已结束")
                    if remaining.isEmpty {
                        Text(featured == nil ? "今天没有登记的课程。" : "这一刻，只留给上面的角色。")
                            .font(.subheadline).foregroundStyle(Palette.muted)
                            .padding(.vertical, 24).frame(maxWidth: .infinity)
                            .overlay(alignment: .bottom) { Divider() }
                    } else {
                        VStack(spacing: 0) {
                            Divider()
                            ForEach(remaining) { course in CourseCard(course: course, now: context.date) }
                        }
                    }
                    Button(action: openChat) {
                        HStack {
                            Text(featured == nil ? "把空白说给我听" : "和\(character.name)说两句")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }.font(.subheadline).padding(.vertical, 16).foregroundStyle(Palette.muted)
                            .overlay(alignment: .bottom) { Divider() }
                    }.buttonStyle(.plain)
                    Text(store.aiReady ? "AI 已配置 · 回应需要网络" : "离线互动 · 在设置中接通 AI")
                        .font(.caption).foregroundStyle(Palette.muted).frame(maxWidth: .infinity)
                }.padding(.horizontal, 24).padding(.bottom, 26)
            }.background(Palette.paper).foregroundStyle(Palette.ink)
        }.navigationBarTitleDisplayMode(.inline)
    }
}

struct CourseCard: View {
    let course: Course
    var now: Date? = nil
    private var minute: Int? { now.map { ScheduleEngine.minute(of: $0) } }
    private var isCurrent: Bool { minute.map { $0 >= course.startMinute && $0 < course.endMinute } ?? false }
    private var status: String {
        guard let minute else { return "编辑" }
        return isCurrent ? "上课中" : minute >= course.endMinute ? "已结束" : "稍后"
    }
    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(Course.clock(course.startMinute)).font(.system(.title3, design: .rounded, weight: .semibold))
                Text(Course.clock(course.endMinute)).font(.caption).foregroundStyle(Palette.muted)
            }.frame(width: 58, alignment: .leading)
            Rectangle().fill(Palette.ink.opacity(0.13)).frame(width: 1, height: 38)
            VStack(alignment: .leading, spacing: 7) {
                Text(course.title).font(.system(.headline, design: .rounded))
                Label(course.room.isEmpty ? "教室待定" : course.room, systemImage: "mappin")
                    .font(.caption).foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 0)
            VStack(spacing: 3) {
                Text(SubjectCharacterKind(courseTitle: course.title).name).font(.system(size: 20, design: .serif))
                Text(status).font(.caption2)
            }.foregroundStyle(Palette.muted)
        }.padding(.vertical, 15).frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottom) { Divider() }
            .overlay(alignment: .leading) { if isCurrent { Rectangle().fill(Palette.ink).frame(width: 3) } }
            .opacity(minute.map { $0 >= course.endMinute ? 0.55 : 1 } ?? 1)
            .foregroundStyle(Palette.ink)
    }
}

private struct MomentCard: View {
    let phase: SchedulePhase
    let now: Date
    let featured: Course?
    private var heading: String {
        switch phase {
        case .noClasses: return "今天，留一点空白"
        case .before: return "下一节，慢慢准备"
        case .inClass: return "现在，它正在成为这门课"
        case .between: return "课间，下一位已经到了"
        case .finished: return "最后一位，转过身来了"
        }
    }
    private var timing: String {
        let minute = ScheduleEngine.minute(of: now)
        switch phase {
        case .before(let course), .between(let course): return "距开始还有 \(course.startMinute - minute) 分钟。"
        case .inClass(let course): return "还剩 \(course.endMinute - minute) 分钟。它会在下课时完成。"
        case .finished: return "今天登记的课程，都已到结束时间。"
        case .noClasses: return "没有登记的课程。不必把每一格填满。"
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Text(heading).font(.subheadline); Spacer(); Text("此刻").font(.caption2) }
                .foregroundStyle(Palette.muted)
            if let featured {
                Text(featured.title).font(.system(.title2, design: .rounded, weight: .semibold))
                HStack {
                    Label(featured.room.isEmpty ? "教室待定" : featured.room, systemImage: "mappin.and.ellipse")
                    Spacer()
                    Text(featured.timeLabel).monospacedDigit()
                }.font(.subheadline)
            }
            Text(timing).font(.subheadline).foregroundStyle(Palette.muted)
        }.padding(.vertical, 17).frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .top) { Divider() }.overlay(alignment: .bottom) { Divider() }
            .accessibilityElement(children: .combine)
    }
}

private extension ScheduleEngine {
    static func minute(of date: Date) -> Int {
        calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
    }
}
