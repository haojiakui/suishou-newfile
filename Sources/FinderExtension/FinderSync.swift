// Finder 扩展只提供目录上下文和菜单；文件写入由主程序处理。
import AppKit
import FinderSync

@objc(FinderSync)
final class FinderSync: FIFinderSync {
    override init() {
        super.init()
        // 桌面由 Finder 的独立视图管理，须显式注册真实桌面，而非扩展沙盒中的 Desktop。
        let desktop = URL(fileURLWithPath: NSHomeDirectoryForUser(NSUserName())!, isDirectory: true)
            .appendingPathComponent("Desktop", isDirectory: true)
        FIFinderSyncController.default().directoryURLs = [
            URL(fileURLWithPath: "/", isDirectory: true), desktop, desktop.resolvingSymlinksInPath()
        ]
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        guard menuKind == .contextualMenuForContainer || menuKind == .contextualMenuForItems,
              let target = FIFinderSyncController.default().targetedURL(), target.isFileURL
        else { return nil }
        if menuKind == .contextualMenuForItems {
            guard let selected = FIFinderSyncController.default().selectedItemURLs(),
                  selected.count == 1,
                  (try? selected[0].resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            else { return nil }
        }
        return MenuBuilder.finderMenu(target: self, action: #selector(createFile(_:)))
    }

    @objc private func createFile(_ sender: NSMenuItem) {
        guard let action = CreateRequest.action(forMenuTag: sender.tag),
              let directory = FIFinderSyncController.default().targetedURL(), directory.isFileURL
        else { return }
        NSWorkspace.shared.open(CreateRequest(action: action, directory: directory).url)
    }
}
