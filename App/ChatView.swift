import SwiftUI

struct ChatView: View {
    @EnvironmentObject private var store: AppStore
    @State private var draft = ""
    @State private var clear = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                SubjectCharacterDrawing(kind: .seed, progress: 1, isInstrument: false)
                    .frame(width: 68, height: 52).foregroundStyle(Palette.ink)
                VStack(alignment: .leading, spacing: 4) {
                    Text("和今天的角色说两句").font(.headline)
                    Text(store.aiReady ? "AI 对话 · 发送后使用网络" : "离线互动 · 可在设置中接通 AI")
                        .font(.caption).foregroundStyle(Palette.muted)
                }
                Spacer()
            }.padding(.horizontal, 20)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 18) {
                        if store.snapshot.messages.isEmpty {
                            VStack(spacing: 16) {
                                Text("大事小事，\n都可以放在这里。").font(.system(size: 25, weight: .medium, design: .rounded)).lineSpacing(8)
                                Text("不用组织语言，也不用表现得很开心。").font(.subheadline).foregroundStyle(Palette.muted)
                            }.multilineTextAlignment(.center).padding(.vertical, 50)
                        }
                        ForEach(store.snapshot.messages) { message in
                            HStack {
                                if message.role == .user { Spacer(minLength: 42) }
                                VStack(alignment: .leading, spacing: 7) {
                                    Text(message.text).font(.body).lineSpacing(5).textSelection(.enabled)
                                    if message.isOffline { Text("离线回应").font(.caption2).foregroundStyle(Palette.muted) }
                                }.padding(16)
                                    .background(message.role == .user ? Palette.sage : .white, in: RoundedRectangle(cornerRadius: 21))
                                if message.role == .assistant { Spacer(minLength: 42) }
                            }.id(message.id)
                        }
                        if store.isSending { HStack { ProgressView(); Text("角色正在想…").font(.caption).foregroundStyle(Palette.muted); Spacer() } }
                        Color.clear.frame(height: 1).id("bottom")
                    }.padding(20)
                }.scrollDismissesKeyboard(.interactively)
                    .onChange(of: store.snapshot.messages.count) { _, _ in withAnimation { proxy.scrollTo("bottom", anchor: .bottom) } }
                    .onChange(of: store.isSending) { _, _ in withAnimation { proxy.scrollTo("bottom", anchor: .bottom) } }
                    .onAppear { proxy.scrollTo("bottom", anchor: .bottom) }
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                if store.isSending { Button("停止等待") { store.cancelSend() }.font(.caption) }
                if !store.isSending && store.aiReady && store.snapshot.messages.last?.role == .user {
                    Button("重试上一条消息") { store.retryLastMessage() }.font(.caption)
                }
                HStack(alignment: .bottom, spacing: 10) {
                    TextField("今天过得怎么样？", text: $draft, axis: .vertical)
                        .lineLimit(1...5).padding(15).background(.white, in: RoundedRectangle(cornerRadius: 22))
                        .focused($focused).onChange(of: draft) { _, value in if value.count > 2000 { draft = String(value.prefix(2000)) } }
                    Button {
                        store.send(draft); draft = ""; focused = false
                    } label: { Image(systemName: "arrow.up").font(.headline).frame(width: 48, height: 48).background(Palette.sage, in: Circle()) }
                        .disabled(store.isSending || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityLabel("发送消息")
                }
            }.padding(.horizontal, 18).padding(.vertical, 10).background(Palette.paper)
        }
        .background(Palette.paper).foregroundStyle(Palette.ink).navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) {
            Button { clear = true } label: { Image(systemName: "trash") }.accessibilityLabel("清空聊天记录")
        } }
        .alert("清空本机聊天记录？", isPresented: $clear) {
            Button("清空", role: .destructive) { store.clearMessages() }
            Button("取消", role: .cancel) { }
        } message: { Text("此操作无法撤销。你手动填写的记忆会保留。") }
    }
}
