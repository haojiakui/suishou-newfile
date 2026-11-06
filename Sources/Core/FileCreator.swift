// 文本创建与模板复制共用排他写入规则；任何入口都不能覆盖用户已有文件。
import Foundation

enum CreationError: LocalizedError {
    case invalidName, notDirectory, missingTemplate(String), tooManyDuplicates

    var errorDescription: String? {
        switch self {
        case .invalidName: return "文件名不能为空，也不能包含斜杠、冒号或空字符。"
        case .notDirectory: return "目标不是可用的本地文件夹。"
        case .missingTemplate(let name): return "应用中的空白文档模板缺失：\(name)。"
        case .tooManyDuplicates: return "同名文件数量过多，请换一个文件名。"
        }
    }
}

struct FileCreator {
    let templateDirectory: URL

    func data(forExtension ext: String) throws -> Data {
        switch ext.lowercased() {
        case "txt", "md": return Data()
        case "xml": return Data("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<root />\n".utf8)
        case "rtf": return Data("{\\rtf1\\ansi\\deff0{\\fonttbl{\\f0 Helvetica;}}\\f0\\fs24\n}\n".utf8)
        case "docx", "xlsx", "pptx":
            let name = "blank.\(ext.lowercased())"
            let template = templateDirectory.appendingPathComponent(name)
            guard FileManager.default.fileExists(atPath: template.path) else {
                throw CreationError.missingTemplate(name)
            }
            return try Data(contentsOf: template)
        default: return Data()
        }
    }

    @discardableResult
    func create(kind: FileKind, in directory: URL) throws -> URL {
        try create(name: "未命名.\(kind.fileExtension)",
                   data: data(forExtension: kind.fileExtension), in: directory)
    }

    @discardableResult
    func create(name: String, data: Data, in directory: URL) throws -> URL {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              name != ".", name != "..", !name.contains("/"),
              !name.contains(":"), !name.contains("\0") else { throw CreationError.invalidName }
        guard directory.isFileURL,
              try directory.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true
        else { throw CreationError.notDirectory }

        let nameURL = URL(fileURLWithPath: name)
        let ext = nameURL.pathExtension
        let base = ext.isEmpty ? name : String(name.dropLast(ext.count + 1))
        for index in 1...10000 {
            let candidate = index == 1 ? name : "\(base) \(index)\(ext.isEmpty ? "" : "." + ext)"
            let destination = directory.appendingPathComponent(candidate, isDirectory: false)
            do {
                // 排他创建防止并发点击或其他程序写入同名文件时覆盖内容。
                try data.write(to: destination, options: .withoutOverwriting)
                return destination
            } catch let error as CocoaError where error.code == .fileWriteFileExists {
                continue
            }
        }
        throw CreationError.tooManyDuplicates
    }
}
