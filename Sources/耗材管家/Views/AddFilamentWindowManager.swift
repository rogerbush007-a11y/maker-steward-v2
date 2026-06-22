import SwiftUI
import AppKit

/// 使用 AppKit 的独立窗口（解决 SwiftUI Sheet 中无法输入文本的问题）
struct AddFilamentWindowManager {
    static func show(store: FilamentStore?) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 480),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "新增耗材"
        window.isReleasedWhenClosed = false
        window.center()

        // 用 NSHostingView 承载 SwiftUI 视图（现在里面的 NSTextField 可以正常输入）
        let hostingView = NSHostingView(
            rootView: AddFilamentView(
                store: store,
                onSave: { DispatchQueue.main.async { window.close() } }
            )
        )
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        window.contentView?.addSubview(hostingView)

        if let contentView = window.contentView {
            NSLayoutConstraint.activate([
                hostingView.topAnchor.constraint(equalTo: contentView.topAnchor),
                hostingView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                hostingView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                hostingView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
            ])
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        windowController = window
    }

    private static var windowController: NSWindow?
}
