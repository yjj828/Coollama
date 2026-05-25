import SwiftUI

struct ThinkToggleView: View {
    @EnvironmentObject private var languageStore: AppLanguageStore

    @Bindable var session: ChatSession

    private var usesLevelPicker: Bool {
        ThinkingMode.usesLevelPicker(model: session.model)
    }

    var body: some View {
        HStack(spacing: 8) {
            Toggle(isOn: $session.thinkEnabled) {
                Image(systemName: "brain")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(
                        session.thinkEnabled
                        ? OllamaTheme.accent
                        : OllamaTheme.textSecondary
                    )
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .help(usesLevelPicker ? languageStore.string(.thinkLevelHelp) : languageStore.string(.thinkToggleHelp))
            .animation(.easeInOut(duration: 0.12), value: session.thinkEnabled)

            if usesLevelPicker && session.thinkEnabled {
                Picker("", selection: $session.thinkLevel) {
                    ForEach(ThinkLevel.allCases) { level in
                        Text(level.label(language: languageStore.language)).tag(level.rawValue)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .controlSize(.small)
                .frame(width: 120)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.easeInOut(duration: 0.15), value: session.thinkEnabled)
    }
}
