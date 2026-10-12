import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct TimetableArchive: Codable {
    var version = 1
    var semesterStart: String
    var courses: [Course]
    var isDemo: Bool

    static func dateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = ScheduleEngine.calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        return formatter
    }
    init(snapshot: AppSnapshot) {
        semesterStart = Self.dateFormatter().string(from: snapshot.termStart)
        courses = snapshot.courses
        isDemo = snapshot.isDemo
    }
    static func read(_ data: Data) throws -> TimetableArchive {
        guard data.count <= 1_000_000 else { throw ArchiveError.invalid }
        let archive = try JSONDecoder().decode(Self.self, from: data)
        guard archive.version == 1, archive.courses.count <= 200,
              Set(archive.courses.map(\.id)).count == archive.courses.count,
              archive.courses.allSatisfy(\.isValid), archive.termStart != nil else { throw ArchiveError.invalid }
        return archive
    }
    var termStart: Date? {
        guard let date = Self.dateFormatter().date(from: semesterStart),
              Self.dateFormatter().string(from: date) == semesterStart else { return nil }
        return date
    }
    enum ArchiveError: LocalizedError {
        case invalid
        var errorDescription: String? { "课表文件格式有误。请选择「下课见」导出的 JSON 文件（最多 200 门课程，1 MB）。" }
    }
}

struct TimetableDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(snapshot: AppSnapshot) throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        data = try encoder.encode(TimetableArchive(snapshot: snapshot))
    }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw TimetableArchive.ArchiveError.invalid }
        _ = try TimetableArchive.read(data)
        self.data = data
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct TransferView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var importing = false
    @State private var exporting = false
    @State private var document: TimetableDocument?
    @State private var pending: TimetableArchive?
    @State private var failure: String?

    var body: some View {
        Form {
            Section {
                Button("选择课表 JSON 文件") { importing = true }
                Button("导出当前课表") {
                    do { document = try TimetableDocument(snapshot: store.snapshot); exporting = true }
                    catch { failure = error.localizedDescription }
                }
            } header: { Text("带上你的课表") } footer: {
                Text("首版支持本 App 的 JSON 格式。文件只包含课程与学期日期，不包含聊天、记忆或 AI 密钥。教务网站和图片导入尚未实现。")
            }
            if let pending {
                Section("准备导入") {
                    Text("\(pending.courses.count) 门课程 · 学期日期 \(pending.semesterStart)")
                    if pending.isDemo { Text("这是示例课表，导入后仍标记为示例。").font(.caption) }
                    Text("导入会替换当前课程和学期日期，建议先导出备份。").font(.caption).foregroundStyle(.secondary)
                    Button("确认替换当前课表") { store.replaceTimetable(pending); dismiss() }
                    Button("取消导入", role: .cancel) { self.pending = nil }
                }
            }
        }.navigationTitle("导入与导出")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("完成") { dismiss() } } }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                do {
                    let url = try result.get()
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                    guard size <= 1_000_000 else { throw TimetableArchive.ArchiveError.invalid }
                    pending = try TimetableArchive.read(Data(contentsOf: url))
                } catch { failure = error.localizedDescription }
            }
            .fileExporter(isPresented: $exporting, document: document, contentType: .json, defaultFilename: "下课见-课表") { result in
                if case .failure(let error) = result { failure = error.localizedDescription }
            }
            .alert("课表没有导入或导出", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
                Button("知道了") { failure = nil }
            } message: { Text(failure ?? "") }
    }
}
