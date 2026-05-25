import SwiftUI

struct ModelPickerView: View {
    @EnvironmentObject private var languageStore: AppLanguageStore

    @Binding var selectedModel: String
    let models: [OllamaModelInfo]

    private var isSelectedModelMissing: Bool {
        !selectedModel.isEmpty && !models.contains { $0.name == selectedModel }
    }

    var body: some View {
        HStack(spacing: 2) {
            Text(languageStore.string(.model))
                .font(.callout)
                .foregroundStyle(OllamaTheme.textSecondary)

            if models.isEmpty && selectedModel.isEmpty {
                Text(languageStore.string(.noAvailableModels))
                    .font(.callout)
                    .foregroundStyle(OllamaTheme.textTertiary)
            } else {
                Picker("", selection: $selectedModel) {
                    if isSelectedModelMissing {
                        Text("\(selectedModel) (\(languageStore.string(.unavailable)))")
                            .tag(selectedModel)
                    }
                    ForEach(models) { model in
                        Text(model.name).tag(model.name)
                    }
                }
                .labelsHidden()
                .font(.callout)
                .frame(maxWidth: 150)
            }
        }
    }
}
