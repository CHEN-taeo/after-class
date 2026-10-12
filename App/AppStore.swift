import Foundation
import Combine

@MainActor final class AppStore: ObservableObject {
    @Published private(set) var snapshot: AppSnapshot
    @Published var mood: PetMood = .happy
    @Published var action: PetAction = .idle
    @Published var bubble = "这一段是课程时间。我在这里，安静一点。"
    @Published var isSending = false
    @Published var error: String?
    @Published var celebration = 0
    @Published private(set) var isResting = false
    private var sendTask: Task<Void, Never>?
    private var interactionTask: Task<Void, Never>?
    private let fileURL: URL
    private var loadFailed = false
    private var lastInteraction = Date.distantPast

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AfterClass/state.json")
        if FileManager.default.fileExists(atPath: self.fileURL.path) {
            do {
                let data = try Data(contentsOf: self.fileURL)
                let restored = try JSONDecoder().decode(AppSnapshot.self, from: data)
                guard restored.schemaVersion == 1, restored.courses.allSatisfy(\.isValid) else { throw AIError.invalidReply }
                snapshot = restored
            } catch {
                snapshot = .demo()
                loadFailed = true
                self.error = "保存的数据暂时无法读取，原文件已保留。本次显示示例，修改不会覆盖原文件。"
            }
        } else { snapshot = .demo() }
    }
    var aiReady: Bool { snapshot.ai.enabled && !snapshot.ai.model.isEmpty && !(Keychain.read() ?? "").isEmpty }
    func save() {
        guard !loadFailed else { error = "原数据读取失败，为保护原文件，本次修改没有保存。"; return }
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch { self.error = "保存失败，请检查设备剩余空间。\(error.localizedDescription)" }
    }
    func upsert(_ course: Course) {
        guard course.isValid else { error = "请检查课程名称、时间和周次。"; return }
        guard snapshot.courses.count < 200 || snapshot.courses.contains(where: { $0.id == course.id }) else {
            error = "首版最多保存 200 门课程。"; return
        }
        if let index = snapshot.courses.firstIndex(where: { $0.id == course.id }) { snapshot.courses[index] = course }
        else { snapshot.courses.append(course) }
        save()
    }
    func delete(_ course: Course) { snapshot.courses.removeAll { $0.id == course.id }; save() }
    func startOwnTimetable() { snapshot.courses = []; snapshot.isDemo = false; save() }
    func replaceTimetable(_ archive: TimetableArchive) {
        guard let date = archive.termStart else { return }
        snapshot.termStart = ScheduleEngine.monday(containing: date)
        snapshot.courses = archive.courses; snapshot.isDemo = archive.isDemo; save()
    }
    func setTermStart(_ date: Date) { snapshot.termStart = ScheduleEngine.monday(containing: date); save() }
    func updateSettings(memory: String, configuration: AIConfiguration, key: String) throws {
        var configuration = configuration
        configuration.model = configuration.model.trimmingCharacters(in: .whitespacesAndNewlines)
        configuration.baseURL = configuration.baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !configuration.enabled || (!configuration.model.isEmpty && !key.isEmpty) else {
            throw AIError.configuration
        }
        if configuration.enabled { _ = try AIClient.endpoint(for: configuration.baseURL) }
        try Keychain.write(key.trimmingCharacters(in: .whitespacesAndNewlines))
        cancelSend()
        snapshot.memory = String(memory.prefix(1000))
        snapshot.ai = configuration
        save()
    }
    func clearMessages() { cancelSend(); snapshot.messages = []; save() }
    func cancelSend() { sendTask?.cancel(); sendTask = nil; isSending = false }
    func retryLastMessage() {
        guard aiReady, !isSending, let last = snapshot.messages.last, last.role == .user else { return }
        snapshot.messages.removeLast()
        error = nil
        send(last.text)
    }

    func interact(_ kind: String) {
        lastInteraction = Date()
        interactionTask?.cancel()
        if kind == "rest" {
            isResting.toggle()
            if isResting { mood = .sleepy; action = .rest; bubble = "收到，一起进入低功耗模式。想回来时，再叫我。" }
            else { action = .idle; lastInteraction = .distantPast; refreshGreeting(now: Date()) }
            return
        }
        guard !isResting else { return }
        switch kind {
        case "celebrate": mood = .delighted; action = .celebrate; bubble = "经费有限，场面是真心的。"; celebration += 1
        default:
            mood = .delighted; action = .bounce
            bubble = ["戳到了！今天也是软软的一只。", "我没有偷懒，我在等你。", "别戳啦，最后一口饼干分你。"].randomElement()!
        }
        interactionTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.action = .idle
        }
    }

    func send(_ raw: String) {
        let text = String(raw.trimmingCharacters(in: .whitespacesAndNewlines).prefix(2000))
        guard !text.isEmpty, !isSending else { return }
        if isResting { isResting = false; action = .idle }
        lastInteraction = Date()
        interactionTask?.cancel()
        snapshot.messages.append(ChatMessage(role: .user, text: text))
        snapshot.messages = Array(snapshot.messages.suffix(200))
        save()
        guard aiReady else {
            let answer: String
            if text.contains("累") || text.contains("困") { answer = "嗯。先在这里停一会儿。"; mood = .sleepy }
            else if text.contains("成功") || text.contains("开心") { answer = "这件事，值得记一下。"; mood = .delighted; celebration += 1 }
            else { answer = "我听见了。现在是离线互动；接通 AI 后，会由今天的学科角色接着聊。"; mood = .calm }
            bubble = answer
            snapshot.messages.append(ChatMessage(role: .assistant, text: answer, isOffline: true))
            save()
            return
        }
        isSending = true
        let captured = snapshot
        let key = Keychain.read() ?? ""
        sendTask = Task { [weak self] in
            do {
                let reply = try await AIClient().reply(configuration: captured.ai, key: key, snapshot: captured)
                guard !Task.isCancelled, let self else { return }
                if !self.isResting {
                    self.mood = reply.mood; self.action = reply.action; self.bubble = reply.text
                    if reply.action == .celebrate { self.celebration += 1 }
                }
                self.snapshot.messages.append(ChatMessage(role: .assistant, text: reply.text))
                self.save(); self.isSending = false
            } catch {
                guard !Task.isCancelled, let self else { return }
                self.isSending = false
                self.error = error.localizedDescription
                if !self.isResting { self.bubble = "信号打了个盹。你的话还在，可以稍后重试。" }
            }
        }
    }

    func refreshGreeting(now: Date) {
        guard !isResting, now.timeIntervalSince(lastInteraction) > 180, !isSending else { return }
        switch ScheduleEngine.phase(at: now, snapshot: snapshot) {
        case .noClasses: bubble = "今天的课表空空的，刚好装一点快乐。"; mood = .calm
        case .before: bubble = "下一节的时间和地点，都放在这里了。"; mood = .happy
        case .inClass: bubble = "这一段是课程时间。我在这里，安静一点。"; mood = .happy
        case .between: bubble = "课表留了个空档，要一起发呆吗？"; mood = .curious
        case .finished: bubble = "课表上的最后一节结束啦。走哇！"; mood = .delighted
        }
    }
}
