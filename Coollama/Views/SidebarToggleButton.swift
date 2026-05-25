import SwiftUI

struct SidebarToggleButton: View {
    @EnvironmentObject private var languageStore: AppLanguageStore

    @Binding var columnVisibility: NavigationSplitViewVisibility

    private var isSidebarVisible: Bool {
        columnVisibility != .detailOnly
    }

    var body: some View {
        Button(action: toggleSidebar) {
            Image(systemName: "sidebar.left")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(OllamaTheme.textSecondary)
                .symbolVariant(isSidebarVisible ? .fill : .none)
        }
        .buttonStyle(.plain)
        .help(isSidebarVisible ? languageStore.string(.collapseSidebar) : languageStore.string(.expandSidebar))
    }

    private func toggleSidebar() {
        withAnimation(.easeInOut(duration: 0.2)) {
            columnVisibility = isSidebarVisible ? .detailOnly : .all
        }
    }
}
