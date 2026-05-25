import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var languageStore: AppLanguageStore
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        Form {
            Section(languageStore.string(.settingsServiceSection)) {
                TextField(languageStore.string(.serviceAddressPlaceholder), text: $viewModel.baseURL)
                    .textFieldStyle(.roundedBorder)

                if let host = viewModel.remoteHost {
                    Label {
                        Text(languageStore.format(.remoteHostWarning, host))
                            .font(.caption)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                    }
                    .foregroundStyle(OllamaTheme.warningText)
                }

                HStack {
                    Button(languageStore.string(.testConnection)) {
                        Task { await viewModel.testConnection() }
                    }
                    connectionIndicator
                    Spacer()
                    if !viewModel.statusMessage.isEmpty {
                        Text(viewModel.statusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section(languageStore.string(.defaultOptionsSection)) {
                Picker(languageStore.string(.defaultModel), selection: $viewModel.defaultModel) {
                    if viewModel.availableModels.isEmpty {
                        Text(languageStore.string(.noModel)).tag("")
                    } else {
                        ForEach(viewModel.availableModels) { model in
                            Text(model.name).tag(model.name)
                        }
                    }
                }

                Button {
                    Task { await viewModel.refreshModels() }
                } label: {
                    Label(languageStore.string(.refreshModels), systemImage: "arrow.clockwise")
                }

                Toggle(languageStore.string(.defaultThinkEnabled), isOn: $viewModel.defaultThinkEnabled)
            }

            Section(languageStore.string(.appearanceSection)) {
                Picker(languageStore.string(.theme), selection: $viewModel.appearance) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.label(language: languageStore.language)).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: viewModel.appearance) { _, _ in
                    scheduleSave()
                }
            }

            Section(languageStore.string(.languageSection)) {
                Picker(languageStore.string(.language), selection: $viewModel.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.nativeName).tag(language)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: viewModel.language) { _, _ in
                    scheduleSave()
                }
            }

            Section {
                Button(languageStore.string(.save)) {
                    viewModel.save(context: modelContext)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 380)
        .padding()
        .onAppear {
            Task { @MainActor in
                await Task.yield()
                viewModel.load(from: modelContext)
            }
        }
        .onDisappear {
            viewModel.save(context: modelContext)
        }
    }

    @ViewBuilder
    private var connectionIndicator: some View {
        switch viewModel.connectionStatus {
        case .unknown:
            Label(languageStore.string(.notTested), systemImage: "circle.dashed")
                .foregroundStyle(.secondary)
        case .testing:
            ProgressView().controlSize(.small)
        case .connected:
            Label(languageStore.string(.connected), systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Label(languageStore.string(.connectionFailed), systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }

    private func scheduleSave() {
        Task { @MainActor in
            await Task.yield()
            viewModel.save(context: modelContext)
        }
    }
}
