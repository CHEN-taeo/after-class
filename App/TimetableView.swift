import SwiftUI
import HorizonCalendar

struct TimetableView: View {
    @EnvironmentObject private var store: AppStore
    @State private var selected = Date()
    @State private var editor: Course?
    @State private var calendarShown = false
    @State private var startOwn = false
    @State private var transferShown = false
    private let labels = ["一", "二", "三", "四", "五", "六", "日"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("你的课表").font(.system(size: 30, weight: .bold, design: .rounded))
                        let week = ScheduleEngine.week(on: selected, termStart: store.snapshot.termStart)
                        Text(week > 0 ? "第 \(week) 周 · 留一点时间发呆" : "还没到开学的日子")
                            .font(.subheadline).foregroundStyle(Palette.muted)
                    }
                    Spacer()
                    Button { calendarShown = true } label: { Image(systemName: "calendar").font(.title3).padding(12) }
                        .accessibilityLabel("选择日期")
                }
                if store.snapshot.isDemo {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("这里是示例课程，不是你的真实课表。").font(.caption)
                        Button("建立我的课表") { startOwn = true }.buttonStyle(SoftButtonStyle())
                    }.foregroundStyle(Palette.muted)
                }
                HStack {
                    Button { moveWeek(-1) } label: { Image(systemName: "chevron.left").padding(12) }.accessibilityLabel("上一周")
                    Spacer()
                    Text(selected.formatted(.dateTime.year().month())).font(.subheadline)
                    Spacer()
                    Button { moveWeek(1) } label: { Image(systemName: "chevron.right").padding(12) }.accessibilityLabel("下一周")
                }
                HStack(spacing: 5) {
                    ForEach(0..<7) { offset in
                        let date = ScheduleEngine.calendar.date(byAdding: .day, value: offset, to: ScheduleEngine.monday(containing: selected))!
                        let active = ScheduleEngine.calendar.isDate(date, inSameDayAs: selected)
                        Button { selected = date } label: {
                            VStack(spacing: 11) {
                                Text(labels[offset]).font(.caption)
                                Text("\(ScheduleEngine.calendar.component(.day, from: date))").font(.system(.headline, design: .rounded))
                                Circle().fill(ScheduleEngine.courses(on: date, snapshot: store.snapshot).isEmpty ? .clear : Palette.muted)
                                    .frame(width: 4, height: 4)
                            }.frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(active ? Palette.sage : Color.clear, in: Capsule())
                        }.buttonStyle(.plain)
                            .accessibilityLabel(date.formatted(.dateTime.month().day().weekday(.wide)))
                            .accessibilityAddTraits(active ? .isSelected : [])
                    }
                }
                let courses = ScheduleEngine.courses(on: selected, snapshot: store.snapshot)
                if courses.isEmpty {
                    ContentUnavailableView("这天留白", systemImage: "leaf", description: Text("还没有登记课程，点右上角添加。"))
                }
                ForEach(courses) { course in
                    Button { editor = course } label: { CourseCard(course: course) }.buttonStyle(.plain)
                }
                Text("点课程可以编辑 · 长一点的空白也很好")
                    .font(.caption).foregroundStyle(Palette.muted).frame(maxWidth: .infinity)
            }.padding(24)
        }.background(Palette.paper).foregroundStyle(Palette.ink)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) {
                HStack {
                Button { transferShown = true } label: { Image(systemName: "square.and.arrow.down") }.accessibilityLabel("导入与导出课表")
                Button { editor = Course(title: "", room: "", weekday: (ScheduleEngine.calendar.component(.weekday, from: selected) + 5) % 7 + 1,
                                         startMinute: 480, endMinute: 575) } label: { Image(systemName: "plus") }.accessibilityLabel("添加课程")
                }
            } }
            .sheet(item: $editor) { course in NavigationStack { CourseEditor(course: course) } }
            .sheet(isPresented: $calendarShown) { NavigationStack { CalendarSheet(selected: $selected) } }
            .sheet(isPresented: $transferShown) { NavigationStack { TransferView() } }
            .alert("建立自己的课表？", isPresented: $startOwn) {
                Button("清空示例，开始填写") { store.startOwnTimetable() }
                Button("暂时保留", role: .cancel) { }
            } message: { Text("当前列表中的示例课程及其修改会被清空，聊天记录会保留。") }
    }
    private func moveWeek(_ delta: Int) {
        selected = ScheduleEngine.calendar.date(byAdding: .day, value: delta * 7, to: selected)!
    }
}

struct CalendarSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: AppStore
    @Binding var selected: Date
    var body: some View {
        let calendar = ScheduleEngine.calendar
        let start = min(calendar.startOfDay(for: selected), store.snapshot.termStart)
        let end = max(selected, calendar.date(byAdding: .day, value: 210, to: store.snapshot.termStart)!)
        CalendarViewRepresentable(calendar: calendar, visibleDateRange: start...end,
                                  monthsLayout: .vertical(options: VerticalMonthsLayoutOptions()), dataDependency: selected)
            .days { day in
                let date = calendar.date(from: day.components)!
                Text("\(day.day)").font(.system(.body, design: .rounded))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(calendar.isDate(date, inSameDayAs: selected) ? Palette.sage : .clear, in: RoundedRectangle(cornerRadius: 12))
            }
            .onDaySelection { day in
                if let date = calendar.date(from: day.components) { selected = date; dismiss() }
            }
            .padding(18).background(Palette.paper).navigationTitle("选一个日子")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("完成") { dismiss() } } }
    }
}

struct CourseEditor: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State var course: Course
    @State private var confirmDelete = false
    private var startTime: Binding<Date> { timeBinding(start: true) }
    private var endTime: Binding<Date> { timeBinding(start: false) }

    var body: some View {
        Form {
            Section("这是什么课") {
                TextField("课程名称", text: $course.title)
                    .onChange(of: course.title) { _, value in if value.count > 60 { course.title = String(value.prefix(60)) } }
                TextField("教室 / 地点", text: $course.room)
                    .onChange(of: course.room) { _, value in if value.count > 80 { course.room = String(value.prefix(80)) } }
                Picker("星期", selection: $course.weekday) {
                    ForEach(1...7, id: \.self) { i in Text(["一", "二", "三", "四", "五", "六", "日"][i - 1]).tag(i) }
                }
                DatePicker("开始", selection: startTime, displayedComponents: .hourAndMinute)
                DatePicker("结束", selection: endTime, displayedComponents: .hourAndMinute)
                if course.endMinute <= course.startMinute { Text("结束时间要晚于开始时间。").foregroundStyle(.red).font(.caption) }
            }
            Section("上课周次") {
                HStack {
                    Button("全选") { course.weeks = Array(1...30) }
                    Spacer()
                    Button("单周") { course.weeks = Array(1...30).filter { $0 % 2 == 1 } }
                    Spacer()
                    Button("双周") { course.weeks = Array(1...30).filter { $0 % 2 == 0 } }
                }.buttonStyle(.borderless)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                    ForEach(1...30, id: \.self) { week in
                        Button {
                            if course.weeks.contains(week) { course.weeks.removeAll { $0 == week } }
                            else { course.weeks.append(week); course.weeks.sort() }
                        } label: {
                            Text("\(week)").font(.caption).frame(maxWidth: .infinity).frame(height: 38)
                                .background(course.weeks.contains(week) ? Palette.sage : Palette.paper, in: RoundedRectangle(cornerRadius: 9))
                        }.buttonStyle(.plain).accessibilityLabel("第\(week)周")
                            .accessibilityAddTraits(course.weeks.contains(week) ? .isSelected : [])
                    }
                }
            }
            Section("颜色") {
                Picker("课程颜色", selection: $course.colorIndex) {
                    ForEach(0..<4) { index in Text(["鼠尾草绿", "浅杏", "淡紫", "雾蓝"][index]).tag(index) }
                }.pickerStyle(.segmented)
            }
            if ScheduleEngine.conflicts(course, among: store.snapshot.courses) {
                Section { Label("与另一门课时间重叠。请核对安排；保存后会同时显示。", systemImage: "exclamationmark.circle").font(.caption) }
            }
            if store.snapshot.courses.contains(where: { $0.id == course.id }) {
                Section { Button("删除这门课", role: .destructive) { confirmDelete = true } }
            }
        }
        .navigationTitle(course.title.isEmpty ? "新的一门课" : "编辑课程")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("保存") { store.upsert(course); dismiss() }.disabled(!course.isValid) }
        }
        .alert("删除这门课？", isPresented: $confirmDelete) {
            Button("删除", role: .destructive) { store.delete(course); dismiss() }
            Button("取消", role: .cancel) { }
        }
    }
    private func timeBinding(start: Bool) -> Binding<Date> {
        Binding(get: {
            ScheduleEngine.calendar.date(byAdding: .minute, value: start ? course.startMinute : course.endMinute,
                                         to: ScheduleEngine.calendar.startOfDay(for: Date()))!
        }, set: { date in
            let minute = ScheduleEngine.calendar.component(.hour, from: date) * 60 + ScheduleEngine.calendar.component(.minute, from: date)
            if start { course.startMinute = minute } else { course.endMinute = minute }
        })
    }
}
