// Finder 的文件选中与文件名编辑是两个状态；仅向 Finder 发送一次编辑动作。
import AppKit
import ApplicationServices

enum FinderRenameError: LocalizedError {
    case permissionRequired, finderUnavailable, selectionChanged, editorUnavailable

    var errorDescription: String? {
        switch self {
        case .permissionRequired:
            return "请在系统设置「隐私与安全性 → 辅助功能」中允许「随手新建」，以在创建后直接编辑文件名。"
        case .finderUnavailable: return "文件已创建，但访达当前不可用。"
        case .selectionChanged: return "文件已创建，但访达的选中项已改变，未触发重命名。"
        case .editorUnavailable: return "文件已创建，但访达未进入文件名编辑状态。"
        }
    }
}

@MainActor
enum FinderRename {
    static func requirePermission() throws {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else { throw FinderRenameError.permissionRequired }
    }

    static func beginEditing(_ file: URL, onDesktop: Bool) async throws {
        guard let finder = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first,
              finder.isActive else { throw FinderRenameError.finderUnavailable }
        let app = AXUIElementCreateApplication(finder.processIdentifier)
        // 已有输入框获得焦点时不发送回车，防止提交用户正在编辑的其他文件名。
        var ready = false
        for _ in 0..<40 {
            let focus = attribute(app, kAXFocusedUIElementAttribute)
            let editing = focus.map { attribute($0 as! AXUIElement, kAXRoleAttribute) as? String == kAXTextFieldRole } ?? false
            let selected: Bool
            if onDesktop {
                let desktop = (attribute(app, kAXChildrenAttribute) as? [AXUIElement] ?? []).first {
                    attribute($0, kAXRoleAttribute) as? String == kAXScrollAreaRole
                }
                selected = desktop.map { descendants($0).contains {
                    attribute($0, kAXRoleAttribute) as? String == kAXImageRole &&
                    attribute($0, kAXTitleAttribute) as? String == file.lastPathComponent &&
                    (attribute($0, kAXSelectedAttribute) as? NSNumber)?.boolValue == true
                }} ?? false
            } else {
                selected = true
            }
            if selected && !editing { ready = true; break }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        guard ready, finder.isActive else { throw FinderRenameError.selectionChanged }
        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: 36, keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: 36, keyDown: false)
        else { throw FinderRenameError.editorUnavailable }
        down.postToPid(finder.processIdentifier)
        up.postToPid(finder.processIdentifier)

        // 只等待这一次动作的结果，不能重发回车，否则可能提交或退出文件名编辑。
        for _ in 0..<40 {
            if let focus = attribute(app, kAXFocusedUIElementAttribute), CFGetTypeID(focus) == AXUIElementGetTypeID() {
                let editor = focus as! AXUIElement
                if attribute(editor, kAXRoleAttribute) as? String == kAXTextFieldRole,
                   attribute(editor, kAXValueAttribute) as? String == file.lastPathComponent {
                    return
                }
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        throw FinderRenameError.editorUnavailable
    }

    private static func attribute(_ element: AXUIElement, _ key: String) -> CFTypeRef? {
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(element, key as CFString, &value)
        return value
    }

    private static func descendants(_ element: AXUIElement, depth: Int = 0) -> [AXUIElement] {
        guard depth < 4 else { return [] }
        return [element] + (attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? []).flatMap {
            descendants($0, depth: depth + 1)
        }
    }
}
