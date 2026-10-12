import SwiftUI

enum Palette {
    static let paper = Color(hex: 0xF8F6EF)
    static let ink = Color(hex: 0x303B35)
    static let muted = Color(hex: 0x58675D)
    static let sage = Color(hex: 0xDEE8D2)
    static let peach = Color(hex: 0xF6DFCB)
    static let lavender = Color(hex: 0xE5E1F0)
    static let blue = Color(hex: 0xDEEAF0)
    static let colors = [sage, peach, lavender, blue]
    static func course(_ index: Int) -> Color { colors[((index % colors.count) + colors.count) % colors.count] }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 255) / 255,
                  green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1)
    }
}

struct SoftButtonStyle: ButtonStyle {
    var fill = Palette.sage
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(.subheadline, design: .rounded, weight: .medium))
            .padding(.horizontal, 18).padding(.vertical, 13)
            .foregroundStyle(Palette.ink).background(fill, in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25), value: configuration.isPressed)
    }
}

struct SectionCaption: View {
    let title: String
    let subtitle: String
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.system(.title3, design: .rounded, weight: .bold))
            Spacer()
            Text(subtitle).font(.caption).foregroundStyle(Palette.muted)
        }.foregroundStyle(Palette.ink)
    }
}
