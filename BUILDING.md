# 开发与构建

项目使用 Swift、AppKit 和 Finder Sync。Finder 扩展负责菜单及目标目录，主程序负责创建文件、选中目标并进入 Finder 原生文件名编辑框。文件写入采用排他创建，连续请求依次处理。

安装 Apple Command Line Tools 后，在源码目录执行：

```bash
bash Scripts/build.sh /absolute/path/to/empty-build-directory
bash Scripts/test.sh
```

`Resources/Templates` 包含构建所需的空白 Office 模板。默认构建采用本地 ad-hoc 签名；配置 `NEWFILE_SIGN_IDENTITY` 可选择 Apple 签名身份。面向其他 Mac 分发时，可按 Apple 流程完成 Developer ID 签名与公证。

当前已有 115 项自动化检查，覆盖文件内容、菜单映射、重名处理、路径传递和并发创建。详细验证记录见 [VALIDATION.md](VALIDATION.md)。
