// 扩展进程由 macOS 的标准扩展入口管理。
import Foundation

@_silgen_name("NSExtensionMain")
func extensionMain(_ argc: Int32, _ argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) -> Int32

exit(extensionMain(CommandLine.argc, CommandLine.unsafeArgv))
