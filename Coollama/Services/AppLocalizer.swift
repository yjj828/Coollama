import Foundation

enum AppString {
    case newChat
    case settingsServiceSection
    case serviceAddressPlaceholder
    case remoteHostWarning
    case testConnection
    case defaultOptionsSection
    case defaultModel
    case noModel
    case refreshModels
    case defaultThinkEnabled
    case appearanceSection
    case theme
    case languageSection
    case language
    case save
    case notTested
    case connected
    case connectionFailed
    case saved
    case connectionSucceeded
    case otherChatGenerating
    case stopGeneration
    case stopOtherChatGenerationHelp
    case chooseOrCreateChat
    case startNewChat
    case emptyChatHint
    case generating
    case regenerate
    case regenerateLastResponseHelp
    case interrupted
    case model
    case noAvailableModels
    case unavailable
    case collapseSidebar
    case expandSidebar
    case delete
    case thinkLevelHelp
    case thinkToggleHelp
    case thinking
    case thinkingProcess
    case sendHelp
    case invalidURL
    case unableToConnectOllama
    case decodingFailed
    case cancelled
    case noModelSelected
    case modelNotAvailable
    case requestFailed
    case skippedMalformedStreamLine
    case appearanceSystem
    case appearanceLight
    case appearanceDark
    case thinkLow
    case thinkMedium
    case thinkHigh
    case newChatShortcutHelp
}

enum AppLocalizer {
    static func string(_ key: AppString, language: AppLanguage) -> String {
        switch language {
        case .english:
            english[key] ?? fallback(for: key)
        case .simplifiedChinese:
            simplifiedChinese[key] ?? english[key] ?? fallback(for: key)
        }
    }

    static func format(_ key: AppString, language: AppLanguage, _ arguments: CVarArg...) -> String {
        String(format: string(key, language: language), locale: language.locale, arguments: arguments)
    }

    private static func fallback(for key: AppString) -> String {
        String(describing: key)
    }

    private static let english: [AppString: String] = [
        .newChat: "New Chat",
        .settingsServiceSection: "Ollama Service",
        .serviceAddressPlaceholder: "Service URL",
        .remoteHostWarning: "All chat content will be sent in plain text to %@. Make sure this is a trusted service.",
        .testConnection: "Test Connection",
        .defaultOptionsSection: "Defaults",
        .defaultModel: "Default Model",
        .noModel: "No Model",
        .refreshModels: "Refresh Models",
        .defaultThinkEnabled: "Enable thinking by default for new chats",
        .appearanceSection: "Appearance",
        .theme: "Theme",
        .languageSection: "Language",
        .language: "Language",
        .save: "Save",
        .notTested: "Not Tested",
        .connected: "Connected",
        .connectionFailed: "Connection Failed",
        .saved: "Saved",
        .connectionSucceeded: "Connection successful",
        .otherChatGenerating: "Another chat is generating. Stop it first.",
        .stopGeneration: "Stop Generation",
        .stopOtherChatGenerationHelp: "Another chat is generating. Click to stop it.",
        .chooseOrCreateChat: "Choose or create a chat",
        .startNewChat: "Start a new chat",
        .emptyChatHint: "Choose a model and type a message. Enable Thinking to view the reasoning process.",
        .generating: "Generating",
        .regenerate: "Regenerate",
        .regenerateLastResponseHelp: "Regenerate the last response",
        .interrupted: "Interrupted",
        .model: "Model",
        .noAvailableModels: "No available models",
        .unavailable: "Unavailable",
        .collapseSidebar: "Collapse Sidebar",
        .expandSidebar: "Expand Sidebar",
        .delete: "Delete",
        .thinkLevelHelp: "Reasoning effort (GPT-OSS)",
        .thinkToggleHelp: "Enable or disable thinking (think)",
        .thinking: "Thinking",
        .thinkingProcess: "Thinking Process",
        .sendHelp: "Send (Return)",
        .invalidURL: "Invalid Ollama service URL",
        .unableToConnectOllama: "Unable to connect to Ollama: %@",
        .decodingFailed: "Failed to parse response",
        .cancelled: "Cancelled",
        .noModelSelected: "Select a model first",
        .modelNotAvailable: "Model \"%@\" is not available. Choose another model.",
        .requestFailed: "Request failed",
        .skippedMalformedStreamLine: "Skipped malformed streaming line: %@",
        .appearanceSystem: "System",
        .appearanceLight: "Light",
        .appearanceDark: "Dark",
        .thinkLow: "Low",
        .thinkMedium: "Medium",
        .thinkHigh: "High",
        .newChatShortcutHelp: "New Chat (⌘N)"
    ]

    private static let simplifiedChinese: [AppString: String] = [
        .newChat: "新对话",
        .settingsServiceSection: "Ollama 服务",
        .serviceAddressPlaceholder: "服务地址",
        .remoteHostWarning: "所有对话内容将以明文发送至 %@，请确认这是你信任的服务。",
        .testConnection: "测试连接",
        .defaultOptionsSection: "默认选项",
        .defaultModel: "默认模型",
        .noModel: "无模型",
        .refreshModels: "刷新模型列表",
        .defaultThinkEnabled: "新对话默认开启思考",
        .appearanceSection: "外观",
        .theme: "主题",
        .languageSection: "语言",
        .language: "语言",
        .save: "保存",
        .notTested: "未测试",
        .connected: "已连接",
        .connectionFailed: "连接失败",
        .saved: "已保存",
        .connectionSucceeded: "连接成功",
        .otherChatGenerating: "其他对话正在生成，请先停止",
        .stopGeneration: "停止生成",
        .stopOtherChatGenerationHelp: "其他对话正在生成，点击停止",
        .chooseOrCreateChat: "选择或新建对话",
        .startNewChat: "开始一段新对话",
        .emptyChatHint: "选择模型并输入内容，可开启「思考」查看推理过程",
        .generating: "生成中",
        .regenerate: "重新生成",
        .regenerateLastResponseHelp: "重新生成最后一条回复",
        .interrupted: "已中断",
        .model: "模型",
        .noAvailableModels: "无可用模型",
        .unavailable: "不可用",
        .collapseSidebar: "收起侧栏",
        .expandSidebar: "展开侧栏",
        .delete: "删除",
        .thinkLevelHelp: "推理强度（GPT-OSS）",
        .thinkToggleHelp: "开启/关闭思考过程（think）",
        .thinking: "思考中",
        .thinkingProcess: "思考过程",
        .sendHelp: "发送 (↩)",
        .invalidURL: "Ollama 服务地址无效",
        .unableToConnectOllama: "无法连接 Ollama：%@",
        .decodingFailed: "响应解析失败",
        .cancelled: "已取消",
        .noModelSelected: "请先选择模型",
        .modelNotAvailable: "模型「%@」不存在，请更换模型",
        .requestFailed: "请求失败",
        .skippedMalformedStreamLine: "跳过无法解析的流式行: %@",
        .appearanceSystem: "跟随系统",
        .appearanceLight: "浅色",
        .appearanceDark: "深色",
        .thinkLow: "低",
        .thinkMedium: "中",
        .thinkHigh: "高",
        .newChatShortcutHelp: "新对话 (⌘N)"
    ]
}
