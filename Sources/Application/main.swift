// 主程序接收 Finder 的目录请求，并用本地模板创建文件。
import AppKit
import FinderSync

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var window: NSWindow?
    private var extensionStatus: NSTextField?
    private var receivedRequest = false
    private var creationTask: Task<Void, Never>?

    private var creator: FileCreator {
        FileCreator(templateDirectory: Bundle.main.resourceURL!.appendingPathComponent("Templates"))
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status.button?.image = NSImage(systemSymbolName: "doc.badge.plus", accessibilityDescription: "随手新建")
        status.button?.toolTip = "随手新建"
        let menu = NSMenu()
        let setup = NSMenuItem(title: "随手新建…", action: #selector(showSetup), keyEquivalent: "")
        setup.target = self
        menu.addItem(setup)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出随手新建", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        status.menu = menu
        statusItem = status
        // URL 启动只执行创建；用户主动打开应用时才显示启用说明。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self, !self.receivedRequest else { return }
            self.showSetup()
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        receivedRequest = true
        for url in urls {
            guard let request = CreateRequest(url: url) else { continue }
            let previousTask = creationTask
            // 文件选中与重命名共享 Finder 焦点，连续创建必须依次处理。
            creationTask = Task { @MainActor in
                await previousTask?.value
                do { try await execute(request) }
                catch { NSApp.activate(ignoringOtherApps: true); NSApp.presentError(error) }
            }
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        updateExtensionStatus()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSetup()
        return true
    }

    private func execute(_ request: CreateRequest) async throws {
        try FinderRename.requirePermission()
        let created: URL
        if let kind = FileKind(rawValue: request.action) {
            created = try creator.create(kind: kind, in: request.directory)
        } else if request.action == "custom" {
            guard let name = askFilename(in: request.directory) else { return }
            let ext = (name as NSString).pathExtension
            created = try creator.create(name: name, data: creator.data(forExtension: ext), in: request.directory)
        } else if request.action == "template" {
            NSApp.activate(ignoringOtherApps: true)
            let panel = NSOpenPanel()
            panel.title = "选择要复制的新文件模板"
            panel.prompt = "使用模板"
            panel.canChooseDirectories = false
            panel.allowsMultipleSelection = false
            guard panel.runModal() == .OK, let source = panel.url else { return }
            created = try creator.create(name: source.lastPathComponent, data: Data(contentsOf: source), in: request.directory)
        } else { return }
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
        let onDesktop = request.directory.resolvingSymlinksInPath().standardizedFileURL == desktop.resolvingSymlinksInPath().standardizedFileURL
        try FinderSelection.select(created, onDesktop: onDesktop)
        try await FinderRename.beginEditing(created, onDesktop: onDesktop)
    }

    private func askFilename(in directory: URL) -> String? {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "自定义创建新文件"
        alert.informativeText = "创建位置：\(directory.path)\n请输入含扩展名的文件名。Office 类型使用空白模板，其他未列出的类型创建零字节文件。"
        alert.addButton(withTitle: "创建")
        alert.addButton(withTitle: "取消")
        let field = NSTextField(string: "未命名.txt")
        field.frame = NSRect(x: 0, y: 0, width: 380, height: 24)
        field.setAccessibilityLabel("完整文件名")
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        return field.stringValue
    }

    @objc private func showSetup() {
        if window == nil { buildSetupWindow() }
        updateExtensionStatus()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    @objc private func openExtensionSettings() {
        FIFinderSyncController.showExtensionManagementInterface()
    }

    private func updateExtensionStatus() {
        let enabled = FIFinderSyncController.isExtensionEnabled
        extensionStatus?.stringValue = enabled ? "Finder 扩展已启用" : "Finder 扩展尚未启用"
    }

    private func buildSetupWindow() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 400),
                              styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "随手新建"
        window.isReleasedWhenClosed = false
        window.center()

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        let title = NSTextField(labelWithString: "在桌面和当前文件夹，新建文件。")
        title.font = .systemFont(ofSize: 22, weight: .semibold)
        stack.addArrangedSubview(title)

        let description = NSTextField(wrappingLabelWithString: "桌面或 Finder 文件夹空白处右键 → 新建文件 → 选择类型。\n创建后直接输入文件名，回车确认；桌面保持原位。")
        description.font = .systemFont(ofSize: 14)
        stack.addArrangedSubview(description)

        let formats = NSTextField(wrappingLabelWithString: "TXT · RTF · XML · Word · Excel · PPT · WPS · Markdown\n也可以自定义文件名，或复制你自己的文件模板。\nWPS 入口创建标准 .docx / .xlsx / .pptx 文件，打开方式由系统默认应用决定。")
        formats.font = .systemFont(ofSize: 13)
        formats.textColor = .secondaryLabelColor
        stack.addArrangedSubview(formats)

        let steps = NSTextField(wrappingLabelWithString: "首次使用\n1. 将应用放入「应用程序」文件夹并打开。\n2. 在系统设置的 Finder 扩展中开启「随手新建」。\n3. 回到桌面或普通 Finder 文件夹，在空白处点击右键。")
        steps.font = .systemFont(ofSize: 13)
        stack.addArrangedSubview(steps)

        let status = NSTextField(labelWithString: "")
        status.font = .systemFont(ofSize: 13, weight: .medium)
        extensionStatus = status
        stack.addArrangedSubview(status)

        let button = NSButton(title: "打开 Finder 扩展设置…", target: self, action: #selector(openExtensionSettings))
        button.bezelStyle = .rounded
        button.keyEquivalent = "\r"
        stack.addArrangedSubview(button)

        window.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: window.contentView!.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: window.contentView!.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: window.contentView!.topAnchor, constant: 28),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: window.contentView!.bottomAnchor, constant: -24)
        ])
        self.window = window
    }
}

// 命令行入口复用正式文件创建逻辑，便于在不驱动 Finder 的情况下验收。
if CommandLine.arguments.dropFirst().first == "--create" {
    let args = CommandLine.arguments
    guard args.count == 5, args[1] == "--create", args[3] == "--directory",
          let kind = FileKind(rawValue: args[2]) else {
        fputs("用法：NewFile --create txt --directory /absolute/path\n", stderr)
        exit(2)
    }
    do {
        let creator = FileCreator(templateDirectory: Bundle.main.resourceURL!.appendingPathComponent("Templates"))
        let result = try creator.create(kind: kind, in: URL(fileURLWithPath: args[4], isDirectory: true))
        print(result.path)
    } catch {
        fputs("\(error.localizedDescription)\n", stderr)
        exit(1)
    }
} else {
    MainActor.assumeIsolated {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }
}
