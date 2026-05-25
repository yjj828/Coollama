import SwiftUI
import AppKit

// MARK: - Color hex extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    /// Dynamic color that follows the window's effective appearance (Light / Dark).
    static func dynamic(light: Color, dark: Color) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .vibrantDark, .aqua]) == .darkAqua
                || appearance.bestMatch(from: [.darkAqua, .vibrantDark, .aqua]) == .vibrantDark
            return NSColor(isDark ? dark : light)
        })
    }
}

// MARK: - Theme

enum OllamaTheme {
    // Backgrounds — unified base, same color across surfaces to avoid borders
    static let background = Color.dynamic(
        light: Color(hex: "#FFFFFF"),
        dark:  Color(hex: "#0D1117")
    )
    static let sidebarBackground = background   // same as background → no sidebar divider
    static let surface           = background   // matches page → no box outline
    static let surfaceElevated = Color.dynamic(
        light: Color(hex: "#F2F4F7"),
        dark:  Color(hex: "#161B22")
    )

    // Borders
    /// 与 NavigationSplitView 侧栏分割线一致（系统 separatorColor）
    static let sidebarBorder = Color(nsColor: .separatorColor)
    static let border = Color.dynamic(
        light: Color.black.opacity(0.08),
        dark:  Color.white.opacity(0.06)
    )
    static let borderFocused = Color.dynamic(
        light: Color.black.opacity(0.20),
        dark:  Color.white.opacity(0.20)
    )

    // Text
    static let textPrimary = Color.dynamic(
        light: Color.black.opacity(0.88),
        dark:  Color.white.opacity(0.90)
    )
    static let textSecondary = Color.dynamic(
        light: Color.black.opacity(0.52),
        dark:  Color.white.opacity(0.42)
    )
    static let textTertiary = Color.dynamic(
        light: Color.black.opacity(0.32),
        dark:  Color.white.opacity(0.25)
    )

    // Accent — GitHub-style blue
    static let accent = Color.dynamic(
        light: Color(hex: "#0969DA"),
        dark:  Color(hex: "#58A6FF")
    )
    static let accentMuted = Color.dynamic(
        light: Color(hex: "#0969DA").opacity(0.12),
        dark:  Color(hex: "#58A6FF").opacity(0.15)
    )

    // Message bubbles
    static let userBubble = Color.dynamic(
        light: Color(hex: "#DBE9F8"),
        dark:  Color(hex: "#1F3A5F")
    )

    // Thinking / reasoning block
    static let thinkingTint = Color.dynamic(
        light: Color.black.opacity(0.03),
        dark:  Color.white.opacity(0.025)
    )
    static let thinkingLine = Color.dynamic(
        light: Color(hex: "#0969DA").opacity(0.45),
        dark:  Color(hex: "#58A6FF").opacity(0.45)
    )

    // Status
    static let errorBanner = Color.dynamic(
        light: Color(hex: "#FFE5E5"),
        dark:  Color(hex: "#3D1515")
    )
    static let warningText = Color.dynamic(
        light: Color(hex: "#9A6700"),
        dark:  Color(hex: "#E3B341")
    )
}

// MARK: - Appearance mode

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    func label(language: AppLanguage) -> String {
        switch self {
        case .system: AppLocalizer.string(.appearanceSystem, language: language)
        case .light: AppLocalizer.string(.appearanceLight, language: language)
        case .dark: AppLocalizer.string(.appearanceDark, language: language)
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

// MARK: - Chat content layout

enum ChatContentLayout {
    /// 与 InputBarView 一致的居中列宽比例
    static let widthFraction: CGFloat = 0.95
    /// 列内文字与输入框 TextEditor 一致的内边距
    static let innerHorizontalPadding: CGFloat = 14

    static func sideInset(for containerWidth: CGFloat) -> CGFloat {
        containerWidth * (1 - widthFraction) / 2
    }
}

// MARK: - View modifiers

struct OllamaBackground: ViewModifier {
    let colorScheme: ColorScheme?

    func body(content: Content) -> some View {
        content
            .background(OllamaTheme.background)
            .preferredColorScheme(colorScheme)
    }
}

extension View {
    func ollamaBackground(colorScheme: ColorScheme? = nil) -> some View {
        modifier(OllamaBackground(colorScheme: colorScheme))
    }

}
