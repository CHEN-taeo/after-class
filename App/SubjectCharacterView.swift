import SwiftUI

enum SubjectCharacterKind: Equatable {
    case compass, fold, comma, cam, spring, probe, seed

    init(courseTitle: String) {
        if courseTitle.range(of: "高等数学|数学|微积分|线性代数|概率", options: .regularExpression) != nil { self = .compass }
        else if courseTitle.range(of: "工程制图|制图|设计表达|CAD|画法几何", options: .regularExpression) != nil { self = .fold }
        else if courseTitle.range(of: "英语|语言|写作|语文", options: .regularExpression) != nil { self = .comma }
        else if courseTitle.range(of: "机械|机原|机构|齿轮", options: .regularExpression) != nil { self = .cam }
        else if courseTitle.range(of: "体育|体能|篮球|足球|游泳", options: .regularExpression) != nil { self = .spring }
        else if courseTitle.range(of: "机器人|实验|编程|计算机|电子", options: .regularExpression) != nil { self = .probe }
        else { self = .seed }
    }

    var name: String {
        switch self { case .compass: return "规"; case .fold: return "折"; case .comma: return "逗"; case .cam: return "凸"; case .spring: return "弹"; case .probe: return "试"; case .seed: return "未" }
    }
    var color: Color {
        switch self {
        case .compass: Color(hex: 0x4F63C7); case .fold: Color(hex: 0x178F87); case .comma: Color(hex: 0xD05243)
        case .cam: Color(hex: 0x6D7550); case .spring: Color(hex: 0xD17B3F); case .probe: Color(hex: 0x725EAA); case .seed: Color(hex: 0x657267)
        }
    }
    var hello: String {
        switch self {
        case .compass: "圆合上了。先别急着解下一题。"
        case .fold: "这张纸，终于可以抬头看看你了。"
        case .comma: "先逗留一下。句子晚一点再继续。"
        case .cam: "齿轮停了。现在轮到你松一口气。"
        case .spring: "拉伸一下吧。今天不必一直绷紧。"
        case .probe: "实验结束。失败的数据也算见过世界。"
        case .seed: "我还没有名字。下次再慢慢认识。"
        }
    }
}

struct SubjectCharacterStage: View {
    let course: Course?
    let phase: SchedulePhase
    let now: Date
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var taps = 0
    @State private var customCaption: String?

    private var kind: SubjectCharacterKind { SubjectCharacterKind(courseTitle: course?.title ?? "") }
    private var isInstrument: Bool { if case .inClass = phase { true } else { false } }
    private var progress: Double {
        guard case .inClass(let current) = phase else {
            if case .finished = phase { return 1 }
            return 0
        }
        return min(1, max(0, Double(ScheduleEngine.calendar.component(.hour, from: now) * 60 + ScheduleEngine.calendar.component(.minute, from: now) - current.startMinute) / Double(current.endMinute - current.startMinute)))
    }
    private var status: String {
        switch phase {
        case .noClasses: "今天休息"
        case .before: "起点等待"
        case .inClass: "器物状态 \(Int(progress * 100))%"
        case .between: "下一节准备"
        case .finished: "人物状态"
        }
    }
    private var caption: String {
        if let customCaption { return customCaption }
        switch phase {
        case .noClasses: return "今天没有角色需要赶来。"
        case .before: return "\(kind.name)还没成为器物，可以先看你一眼。"
        case .inClass: return "\(kind.name)正在完成这节课。下课后再见。"
        case .between: return "\(kind.name)已经到了起点，等下一节开始。"
        case .finished: return "\(kind.name)完成了今天最后一段时间。"
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(course.map { "\(kind.name) · \($0.title)" } ?? "未 · 自由留白").fontWeight(.semibold)
                Spacer()
                Text(status).monospacedDigit().foregroundStyle(Palette.muted)
            }.font(.caption)
            Button {
                taps += 1
                customCaption = kind.hello
            } label: {
                SubjectCharacterDrawing(kind: kind, progress: progress, isInstrument: isInstrument,
                                        fallbackInitial: String(course?.title.first ?? "未"))
                    .frame(height: 190)
                    .rotationEffect(.degrees(!reduceMotion && taps.isMultiple(of: 2) ? 0 : 1.5))
                    .offset(y: !reduceMotion && taps.isMultiple(of: 2) ? 0 : -4)
                    .animation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.58), value: taps)
            }
            .buttonStyle(.plain).disabled(isInstrument)
            .accessibilityLabel(isInstrument ? "\(course?.title ?? "课程")上课中，角色暂不回应" : "和\(kind.name)打招呼")
            Text(caption).font(.subheadline).foregroundStyle(Palette.muted).multilineTextAlignment(.center).frame(maxWidth: .infinity)
        }
        .foregroundStyle(kind.color).padding(.vertical, 10)
        .overlay(alignment: .bottom) { Divider() }
        .onChange(of: phase) { _, _ in customCaption = nil }
    }
}

struct SubjectCharacterDrawing: View {
    let kind: SubjectCharacterKind
    let progress: Double
    let isInstrument: Bool
    var fallbackInitial = "未"

    var body: some View {
        Canvas { context, size in
            context.scaleBy(x: size.width / 252, y: size.height / 178)
            let color = kind.color
            let stroke = StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
            func line(_ points: [CGPoint], opacity: Double = 1) {
                var path = Path(); guard let first = points.first else { return }; path.move(to: first)
                for point in points.dropFirst() { path.addLine(to: point) }
                var copy = context; copy.opacity = opacity; copy.stroke(path, with: .color(color), style: stroke)
            }
            func ellipse(_ rect: CGRect, fill: Bool = false) {
                let path = Path(ellipseIn: rect)
                if fill { context.fill(path, with: .color(color)) } else { context.stroke(path, with: .color(color), style: stroke) }
            }
            switch kind {
            case .compass:
                var arc = Path(); arc.addArc(center: CGPoint(x: 126, y: 112), radius: 66, startAngle: .degrees(195), endAngle: .degrees(195 + 330 * progress), clockwise: false)
                context.stroke(arc, with: .color(color), style: stroke); ellipse(CGRect(x: 117, y: 47, width: 18, height: 18))
                line([CGPoint(x: 121, y: 64), CGPoint(x: 86, y: 139)]); line([CGPoint(x: 131, y: 64), CGPoint(x: 166, y: 139)])
                line([CGPoint(x: 75, y: 139), CGPoint(x: 98, y: 139)]); line([CGPoint(x: 154, y: 139), CGPoint(x: 177, y: 139)])
            case .fold:
                let panels = [(CGRect(x: 62,y:48,width:50,height:42),0.05),(CGRect(x:112,y:48,width:50,height:42),0.28),(CGRect(x:112,y:90,width:50,height:42),0.5),(CGRect(x:162,y:90,width:40,height:42),0.72),(CGRect(x:72,y:132,width:40,height:32),0.9)]
                for (rect, threshold) in panels {
                    var panel = Path(); panel.addRect(rect)
                    var copy = context; copy.opacity = progress >= threshold ? 1 : 0.12; copy.stroke(panel, with: .color(color), style: stroke)
                }
                line([CGPoint(x:112,y:48),CGPoint(x:112,y:132)]); line([CGPoint(x:62,y:90),CGPoint(x:202,y:90)])
            case .comma:
                line([CGPoint(x:45,y:68),CGPoint(x:45 + 112 * progress,y:68)]); line([CGPoint(x:45,y:101),CGPoint(x:45 + 148 * progress,y:101)]); line([CGPoint(x:45,y:134),CGPoint(x:45 + 92 * progress,y:134)])
                var comma = Path(); comma.move(to: CGPoint(x:170,y:48)); comma.addCurve(to: CGPoint(x:173,y:120), control1: CGPoint(x:218,y:45), control2: CGPoint(x:205,y:103)); comma.addCurve(to: CGPoint(x:178,y:92), control1: CGPoint(x:187,y:103), control2: CGPoint(x:188,y:95)); context.stroke(comma, with: .color(color), style: stroke)
            case .cam:
                ellipse(CGRect(x:60,y:43,width:96,height:96)); ellipse(CGRect(x:101,y:84,width:14,height:14)); let angle = progress * .pi * 2 - 0.6
                let tip = CGPoint(x:108 + cos(angle) * 48, y:91 + sin(angle) * 48); line([CGPoint(x:108,y:91),tip,CGPoint(x:187,y:93)]); line([CGPoint(x:187,y:65),CGPoint(x:187,y:121)]); line([CGPoint(x:173,y:121),CGPoint(x:201,y:121)])
            case .spring:
                let width = 35 + 55 * progress; line([CGPoint(x:45,y:90),CGPoint(x:70,y:90),CGPoint(x:84,y:90-width/4),CGPoint(x:84+width/2,y:90+width/4),CGPoint(x:84+width,y:90-width/4),CGPoint(x:84+width*1.5,y:90+width/4),CGPoint(x:188,y:90),CGPoint(x:207,y:90)])
                line([CGPoint(x:45,y:72),CGPoint(x:45,y:108)]); line([CGPoint(x:207,y:72),CGPoint(x:207,y:108)])
            case .probe:
                context.stroke(Path(roundedRect: CGRect(x:70,y:62,width:78,height:66), cornerRadius: 8), with: .color(color), style: stroke)
                line([CGPoint(x:148,y:79),CGPoint(x:179,y:79),CGPoint(x:199,y:102+32*progress)]); line([CGPoint(x:178,y:79),CGPoint(x:178,y:125)]); ellipse(CGRect(x:193,y:96+32*progress,width:12,height:12)); line([CGPoint(x:58,y:139),CGPoint(x:200,y:139)])
            case .seed:
                ellipse(CGRect(x:54,y:34,width:144,height:116)); context.draw(Text(fallbackInitial).font(.system(size:34)).foregroundStyle(color), at: CGPoint(x:126,y:94))
            }
            if !isInstrument {
                ellipse(CGRect(x:112.8,y:79.8,width:6.4,height:6.4), fill: true); ellipse(CGRect(x:132.8,y:79.8,width:6.4,height:6.4), fill: true)
            }
        }.accessibilityHidden(true)
    }
}
