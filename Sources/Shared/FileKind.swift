// Finder 菜单与主程序共享同一份文件类型，避免显示名称与实际格式不一致。
import Foundation

enum FileKind: String, CaseIterable {
    case txt, rtf, xml, word, excel, powerpoint, wpsWriter, wpsSheet, wpsPresentation, markdown

    var title: String {
        switch self {
        case .txt: return "TXT"
        case .rtf: return "RTF"
        case .xml: return "XML"
        case .word: return "Word"
        case .excel: return "Excel"
        case .powerpoint: return "PPT"
        case .wpsWriter: return "WPS 文字"
        case .wpsSheet: return "WPS 表格"
        case .wpsPresentation: return "WPS 演示"
        case .markdown: return "Markdown"
        }
    }

    var fileExtension: String {
        switch self {
        case .txt: return "txt"
        case .rtf: return "rtf"
        case .xml: return "xml"
        case .word, .wpsWriter: return "docx"
        case .excel, .wpsSheet: return "xlsx"
        case .powerpoint, .wpsPresentation: return "pptx"
        case .markdown: return "md"
        }
    }

}

struct CreateRequest {
    static let scheme = "suishou-newfile"
    static let menuActions = ["custom", "template"] + FileKind.allCases.map(\.rawValue)

    static func action(forMenuTag tag: Int) -> String? {
        guard (1...menuActions.count).contains(tag) else { return nil }
        return menuActions[tag - 1]
    }
    let action: String
    let directory: URL

    init(action: String, directory: URL) {
        self.action = action
        self.directory = directory
    }

    init?(url: URL) {
        guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.scheme == Self.scheme, parts.host == "create",
              let items = parts.queryItems, items.count == 2,
              let action = items.first(where: { $0.name == "kind" })?.value,
              let path = items.first(where: { $0.name == "directory" })?.value,
              path.hasPrefix("/"),
              FileKind(rawValue: action) != nil || ["custom", "template"].contains(action)
        else { return nil }
        self.init(action: action, directory: URL(fileURLWithPath: path, isDirectory: true))
    }

    var url: URL {
        var parts = URLComponents()
        parts.scheme = Self.scheme
        parts.host = "create"
        parts.queryItems = [URLQueryItem(name: "kind", value: action),
                            URLQueryItem(name: "directory", value: directory.path)]
        return parts.url!
    }
}
