// 桌面选中只设置 Finder 的 selection，避免 reveal 命令打开桌面目录窗口。
import AppKit
import Carbon

enum FinderSelectionError: LocalizedError {
    case invalidScript
    case selectionFailed(code: Int?, message: String?)

    var errorDescription: String? {
        switch self {
        case .invalidScript:
            return "文件已创建，但访达选中命令无法初始化。"
        case .selectionFailed(let code, _):
            if code == -1743 {
                return "文件已创建。请在系统设置「隐私与安全性 → 自动化」中允许「随手新建」控制「访达」，以编辑新文件名。"
            }
            return "文件已创建，但访达未能选中新文件。"
        }
    }

    var failureReason: String? {
        guard case .selectionFailed(_, let message) = self else { return nil }
        return message
    }
}

@MainActor
enum FinderSelection {
    static func select(_ file: URL, onDesktop: Bool) throws {
        guard let script = NSAppleScript(source: """
            on selectCreatedFile(createdName, createdPath, onDesktop)
                set createdFile to POSIX file createdPath as alias
                tell application id "com.apple.finder"
                    activate
                    if onDesktop then
                        set selection to {file createdName of desktop}
                        return createdPath
                    else
                        reveal createdFile
                    end if
                    repeat 40 times
                        set selectedItems to selection as alias list
                        if (count of selectedItems) is 1 then
                            set selectedPath to POSIX path of (item 1 of selectedItems)
                            if selectedPath is createdPath then return selectedPath
                        end if
                        delay 0.05
                    end repeat
                    return ""
                end tell
            end selectCreatedFile
            """) else { throw FinderSelectionError.invalidScript }

        let event = NSAppleEventDescriptor(eventClass: AEEventClass(kASAppleScriptSuite),
                                          eventID: AEEventID(kASSubroutineEvent),
                                          targetDescriptor: nil,
                                          returnID: AEReturnID(kAutoGenerateReturnID),
                                          transactionID: AETransactionID(kAnyTransactionID))
        event.setParam(NSAppleEventDescriptor(string: "selectcreatedfile"), forKeyword: AEKeyword(keyASSubroutineName))
        let arguments = NSAppleEventDescriptor.list()
        // 文件名通过参数传入，不能拼接进脚本源码；引号、反斜杠等字符仍是文件名。
        arguments.insert(NSAppleEventDescriptor(string: file.lastPathComponent), at: 1)
        arguments.insert(NSAppleEventDescriptor(string: file.path), at: 2)
        arguments.insert(NSAppleEventDescriptor(boolean: onDesktop), at: 3)
        event.setParam(arguments, forKeyword: AEKeyword(keyDirectObject))

        var error: NSDictionary?
        let selected = script.executeAppleEvent(event, error: &error)
        if let error {
            throw FinderSelectionError.selectionFailed(code: error[NSAppleScript.errorNumber] as? Int,
                                                       message: error[NSAppleScript.errorMessage] as? String)
        }
        guard selected.stringValue.map({ URL(fileURLWithPath: $0).resolvingSymlinksInPath().standardizedFileURL }) == file.resolvingSymlinksInPath().standardizedFileURL
        else { throw FinderRenameError.selectionChanged }
    }
}
