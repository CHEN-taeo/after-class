import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var memory = ""
    @State private var configuration = AIConfiguration()
    @State private var key = ""
    @State private var termStart = Date()
    @State private var failure: String?
    @State private var loaded = false

    var body: some View {
        Form {
            Section {
                TextEditor(text: $memory).frame(minHeight: 85)
                    .accessibilityLabel("希望角色记住的事情")
                    .onChange(of: memory) { _, value in if value.count > 1000 { memory = String(value.prefix(1000)) } }
            } header: { Text("希望它记住的小事") } footer: {
                Text("只记住你在这里主动填写的内容。可随时修改或清空；接通 AI 后会随对话发送给你配置的服务。")
            }
            Section("学期") {
                DatePicker("第一周的日期", selection: $termStart, displayedComponents: .date)
                Text("以所选日期所在周的周一作为第 1 周起点。").font(.caption).foregroundStyle(Palette.muted)
            }
            Section {
                Toggle("启用 AI 对话", isOn: $configuration.enabled)
                TextField("接口地址（含 /v1）", text: $configuration.baseURL)
                    .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                TextField("模型名称", text: $configuration.model).textInputAutocapitalization(.never).autocorrectionDisabled()
                SecureField("API 密钥", text: $key).textInputAutocapitalization(.never).autocorrectionDisabled()
                if !key.isEmpty { Button("移除密钥", role: .destructive) { key = ""; configuration.enabled = false } }
            } header: { Text("接通 AI") } footer: {
                Text("支持 OpenAI 兼容的 Chat Completions HTTPS 接口。密钥保存在本机钥匙串。启用后，最近的对话、当天课程标题与时间、你填写的记忆会发送给该服务，可能产生该服务的费用。AI 可能说错话。")
            }
            Section("关于") {
                LabeledContent("下课见", value: "0.1 · 原生预览版")
                NavigationLink("开源致谢") { CreditsView() }
                Text("聊天和课表保存在本机。没有账户同步；卸载前请留意本机数据。")
                    .font(.caption).foregroundStyle(Palette.muted)
            }
        }
        .navigationTitle("一点小设置")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    do {
                        try store.updateSettings(memory: memory, configuration: configuration, key: key)
                        store.setTermStart(termStart)
                        dismiss()
                    } catch { failure = error.localizedDescription }
                }
            }
        }
        .onAppear {
            guard !loaded else { return }
            memory = store.snapshot.memory
            configuration = store.snapshot.ai; key = Keychain.read() ?? ""; termStart = store.snapshot.termStart; loaded = true
        }
        .alert("还差一点", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
            Button("知道了") { failure = nil }
        } message: { Text(failure ?? "") }
    }
}

struct CreditsView: View {
    var body: some View {
        List {
            Section("实际使用") {
                Text("HorizonCalendar · Airbnb\nApache-2.0 · 原生日期选择组件。")
            }
            Section("原创角色") { Text("规、折、逗、凸、弹、试及其器物动画均为本项目绘制。") }
            Section("设计参考") { Text("AIRI：对话与角色状态联动的交互思路。未复制其代码或角色素材。") }
            ForEach(["HorizonCalendar"], id: \.self) { name in
                Section(name) {
                    Text(license(name)).font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
                }
            }
        }.navigationTitle("谢谢这些开源朋友")
    }
    private func license(_ name: String) -> String {
        guard let url = Bundle.main.url(forResource: "\(name)-LICENSE", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return "许可证随源码保存在 ThirdParty 目录。" }
        return text
    }
}
