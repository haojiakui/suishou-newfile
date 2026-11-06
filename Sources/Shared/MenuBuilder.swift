// 使用系统菜单与图标，保留 Finder 的键盘导航、辅助功能和深浅色外观。
import AppKit
import UniformTypeIdentifiers

@MainActor
enum MenuBuilder {
    /// Finder 通过 XPC 后台队列请求菜单；AppKit 菜单须在主线程构建。
    nonisolated static func finderMenu(target: AnyObject, action: Selector) -> NSMenu {
        let build: @MainActor () -> NSMenu = {
            let menu = NSMenu()
            let parent = NSMenuItem(title: "新建文件", action: nil, keyEquivalent: "")
            parent.image = NSImage(systemSymbolName: "doc.badge.plus", accessibilityDescription: "新建文件")
            parent.submenu = submenu(target: target, action: action)
            menu.addItem(parent)
            return menu
        }
        if Thread.isMainThread {
            var menu: NSMenu!
            MainActor.assumeIsolated { menu = build() }
            return menu
        }
        return DispatchQueue.main.sync { build() }
    }

    static func submenu(target: AnyObject, action: Selector) -> NSMenu {
        let menu = NSMenu(title: "新建文件")
        menu.autoenablesItems = false
        for (title, value, type) in [("自定义创建新文件…", "custom", UTType.data),
                                     ("从模板创建…", "template", UTType.folder)] {
            menu.addItem(item(title: title, value: value, type: type,
                              target: target, action: action))
        }
        menu.addItem(.separator())
        for kind in FileKind.allCases {
            let title = "\(kind.title)  (.\(kind.fileExtension))"
            menu.addItem(item(title: title, value: kind.rawValue, type: UTType(filenameExtension: kind.fileExtension)!,
                              target: target, action: action))
        }
        return menu
    }

    private static func item(title: String, value: String, type: UTType,
                             target: AnyObject, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = target
        // Finder 跨进程传递菜单动作时使用标量 tag，不依赖 representedObject。
        item.tag = CreateRequest.menuActions.firstIndex(of: value)! + 1
        // 文件类型图标由系统注册信息决定；不可标记为模板，否则 Finder 会抹去颜色。
        let image = NSWorkspace.shared.icon(for: type).copy() as! NSImage
        image.size = NSSize(width: 16, height: 16)
        image.isTemplate = false
        image.accessibilityDescription = title
        item.image = image
        return item
    }
}
