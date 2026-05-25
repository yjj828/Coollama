import Foundation

/// 当前在详情区展示的会话，用于避免切换侧栏时流式 @Published 触发无关视图刷新
@MainActor
final class ChatSessionFocus: ObservableObject {
    @Published var visibleSessionID: UUID?
}
