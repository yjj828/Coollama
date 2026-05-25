import SwiftUI

struct InputBarView: View {
    @EnvironmentObject private var languageStore: AppLanguageStore

    @Binding var text: String
    var isGenerating: Bool
    var onSend: () -> Void
    var onStop: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TextEditor(text: $text)
                .font(.body)
                .foregroundStyle(OllamaTheme.textPrimary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 38, maxHeight: 140)
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 10)
                .padding(.trailing, 38)
                .focused($isFocused)
                .onKeyPress(keys: [.return]) { press in
                    handleReturnKey(press)
                }

            actionButton
                .padding(.trailing, 8)
                .padding(.bottom, 7)
        }
        .background(OllamaTheme.background)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(inputBorderColor, lineWidth: 1)
        )
        .shadow(color: inputShadowColor, radius: 8, x: 0, y: 1)
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity)
        .background(OllamaTheme.background)
        .animation(.easeInOut(duration: 0.15), value: isFocused)
    }

    /// 浅色：阴影；深色：描边与侧栏分割线同色
    private var inputShadowColor: Color {
        Color.dynamic(
            light: Color.black.opacity(0.10),
            dark:  .clear
        )
    }

    private var inputBorderColor: Color {
        Color.dynamic(
            light: .clear,
            dark:  OllamaTheme.sidebarBorder
        )
    }

    @ViewBuilder
    private var actionButton: some View {
        if isGenerating {
            Button(action: onStop) {
                Image(systemName: "stop.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(OllamaTheme.warningText.opacity(0.85))
            }
            .buttonStyle(.plain)
            .help(languageStore.string(.stopGeneration))
        } else {
            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(
                        canSend
                        ? OllamaTheme.accent
                        : OllamaTheme.textTertiary
                    )
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .help(languageStore.string(.sendHelp))
            .animation(.easeInOut(duration: 0.12), value: canSend)
        }
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// 与原先相反：↩ 发送，⌘↩ / ⇧↩ 换行
    private func handleReturnKey(_ press: KeyPress) -> KeyPress.Result {
        if press.modifiers.contains(.command) {
            text.append("\n")
            return .handled
        }
        if press.modifiers.contains(.shift) {
            return .ignored
        }
        if canSend, !isGenerating {
            onSend()
        }
        return .handled
    }
}
