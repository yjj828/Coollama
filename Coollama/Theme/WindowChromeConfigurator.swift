import AppKit
import SwiftUI

enum WindowMetrics {
    /// 隐藏标题栏后，为左上角窗口按钮预留的顶部间距
    static let titleBarClearance: CGFloat = 28
}

/// 配置无边框标题栏，保留红黄绿窗口按钮（每个窗口只配置一次，避免 ViewBridge 循环）
enum WindowChromeConfigurator {
    static func apply(to window: NSWindow) {
        if !window.styleMask.contains(.fullSizeContentView) {
            window.styleMask.insert(.fullSizeContentView)
        }
        if !window.titlebarAppearsTransparent {
            window.titlebarAppearsTransparent = true
        }
        if window.titleVisibility != .hidden {
            window.titleVisibility = .hidden
        }
        if !window.isMovableByWindowBackground {
            window.isMovableByWindowBackground = true
        }
        if window.backgroundColor != .clear {
            window.backgroundColor = .clear
        }
    }
}

private final class WindowChromeHostingView: NSView {
    private weak var configuredWindow: NSWindow?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window, configuredWindow !== window else { return }
        configuredWindow = window
        WindowChromeConfigurator.apply(to: window)
    }
}

private struct WindowChromeConfiguratorRepresentable: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        WindowChromeHostingView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

extension View {
    func hiddenTitleBarWindow() -> some View {
        background(WindowChromeConfiguratorRepresentable())
    }
}
