import AppKit
import Foundation

var checks = 0
func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fputs("FAIL: \(message)\n", stderr); exit(1) }
    checks += 1
}

let templates = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let sandbox = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
try FileManager.default.createDirectory(at: sandbox, withIntermediateDirectories: true)
let folder = sandbox.appendingPathComponent("中文 空格 & # % + ? 文件夹", isDirectory: true)
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
let creator = FileCreator(templateDirectory: templates)

for kind in FileKind.allCases {
    let created = try creator.create(kind: kind, in: folder)
    check(created.deletingLastPathComponent() == folder, "创建目录必须保持不变")
    check(created.pathExtension == kind.fileExtension, "实际扩展名必须与菜单一致")
    check(try! Data(contentsOf: created) == creator.data(forExtension: kind.fileExtension), "文件内容必须来自对应模板")
    let request = CreateRequest(action: kind.rawValue, directory: folder)
    check(CreateRequest(url: request.url)?.directory.path == folder.path, "特殊字符路径必须能通过 URL 无损传递")
    check(CreateRequest(url: request.url)?.action == kind.rawValue, "请求类型必须无损传递")
}

let protected = folder.appendingPathComponent("保留.txt")
try Data("原始内容，不允许覆盖".utf8).write(to: protected)
let duplicate = try creator.create(name: "保留.txt", data: Data(), in: folder)
check(duplicate.lastPathComponent == "保留 2.txt", "重名文件必须添加序号")
check(try! String(contentsOf: protected, encoding: .utf8) == "原始内容，不允许覆盖", "重名时保留原文件内容")

for invalid in ["", " ", ".", "..", "../越界.txt", "a/b.txt", "a:b.txt", "a\0b.txt"] {
    do { _ = try creator.create(name: invalid, data: Data(), in: folder); check(false, "非法文件名必须拒绝") }
    catch CreationError.invalidName { checks += 1 }
}

do {
    _ = try creator.create(kind: .txt, in: protected)
    check(false, "文件不能作为创建目标目录")
} catch CreationError.notDirectory { checks += 1 }

let noExtension = try creator.create(name: "LICENSE", data: Data(), in: folder)
let noExtension2 = try creator.create(name: "LICENSE", data: Data(), in: folder)
check(noExtension.lastPathComponent == "LICENSE" && noExtension2.lastPathComponent == "LICENSE 2", "无扩展名文件重名规则")

let hidden = try creator.create(name: ".gitignore", data: Data(), in: folder)
check(hidden.lastPathComponent == ".gitignore", "允许有效隐藏文件名")

let missing = FileCreator(templateDirectory: sandbox.appendingPathComponent("missing"))
do { _ = try missing.create(kind: .word, in: folder); check(false, "缺失文档模板必须报错") }
catch CreationError.missingTemplate { checks += 1 }

for value in ["https://create?kind=txt&directory=/tmp", "suishou-newfile://create?kind=bad&directory=/tmp", "suishou-newfile://create?kind=txt&directory=relative", "suishou-newfile://create?kind=txt&kind=word"] {
    check(CreateRequest(url: URL(string: value)!) == nil, "拒绝非法 URL 请求")
}

check(CreateRequest.action(forMenuTag: 0) == nil, "未设置的菜单 tag 不触发创建")
check(CreateRequest.action(forMenuTag: 999) == nil, "非法菜单 tag 不触发创建")
check(Set(CreateRequest.menuActions).count == CreateRequest.menuActions.count, "每个菜单动作有唯一 tag")
let lock = NSLock()
var paths = Set<String>()
var concurrencyErrors = [String]()
DispatchQueue.concurrentPerform(iterations: 32) { _ in
    do {
        let result = try creator.create(name: "并发.txt", data: Data("test".utf8), in: folder)
        lock.lock(); paths.insert(result.path); lock.unlock()
    } catch {
        lock.lock(); concurrencyErrors.append(error.localizedDescription); lock.unlock()
    }
}
check(concurrencyErrors.isEmpty, "并发创建不能因文件名竞争而失败")
check(paths.count == 32, "32 次并发创建必须产生 32 个不同文件")

MainActor.assumeIsolated {
    let menu = MenuBuilder.submenu(target: NSObject(), action: NSSelectorFromString("create:"))
    check(menu.items.count == FileKind.allCases.count + 3, "菜单覆盖自定义、模板和所有预设类型")
    check(menu.items[2].isSeparatorItem, "预设类型与自定义操作分组")
    for item in menu.items where !item.isSeparatorItem {
        check(item.isEnabled, "所有创建入口默认可用")
        check(item.image != nil, "所有创建入口都有系统图标")
        check(CreateRequest.action(forMenuTag: item.tag) != nil, "菜单 tag 能解析为有效创建动作")
    }
}

// 模拟 Finder 的后台 XPC 回调，同时让主线程处理菜单构建任务。
let finished = DispatchSemaphore(value: 0)
DispatchQueue.global().async {
    let menu = MenuBuilder.finderMenu(target: NSObject(), action: NSSelectorFromString("create:"))
    check(menu.items.first?.title == "新建文件", "后台请求能构建 Finder 菜单而不触发主线程断言")
    check(menu.items.first?.submenu?.items.count == FileKind.allCases.count + 3, "后台请求返回完整二级菜单")
    finished.signal()
}
let deadline = Date().addingTimeInterval(5)
var completed = false
while Date() < deadline {
    if finished.wait(timeout: .now()) == .success { completed = true; break }
    RunLoop.main.run(until: Date().addingTimeInterval(0.01))
}
check(completed, "后台菜单请求应完成，不能死锁")
MainActor.assumeIsolated {
    let menu = MenuBuilder.finderMenu(target: NSObject(), action: NSSelectorFromString("create:"))
    check(menu.items.first?.title == "新建文件", "主线程请求同样可以完成菜单构建")
}
print("PASS: \(checks) checks, including 32 concurrent creates and main/background menu requests")
