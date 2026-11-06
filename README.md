# 随手新建

在 macOS 桌面和 Finder 文件夹中，通过右键菜单快速创建文件。选好类型后直接输入文件名，按回车完成。

## 功能

- **右键新建**：在桌面或当前文件夹的空白处选择「新建文件」。
- **直接命名**：创建后自动进入文件名编辑框，默认保留扩展名；桌面文件在桌面原位完成创建和命名。
- **多种格式**：支持 TXT、RTF、XML、Word、Excel、PPT、WPS 和 Markdown。
- **自定义文件**：输入完整文件名，或选择自己的文件作为模板。
- **自动处理重名**：已有同名文件时，在名称后添加序号，例如「未命名 2.txt」，保留已有文件。
- **系统文件图标**：使用 macOS 提供的文件类型图标，保留原有颜色。

## 安装

从 [GitHub Releases](https://github.com/haojiakui/suishou-newfile/releases/latest) 下载 Apple Silicon 安装包，解压后将「随手新建.app」拖入「应用程序」文件夹。

系统要求为 macOS 13 或更新版本，已在 macOS 26.4 / Apple Silicon 环境验证。当前安装包采用本地 ad-hoc 签名，加载遵循所在 Mac 的系统安全策略。

首次打开后完成以下设置：

1. 点击「打开 Finder 扩展设置…」，启用「随手新建」。macOS 26 的入口通常位于「通用 → 登录项与扩展 → 扩展 → Finder」。
2. 在「隐私与安全性 → 辅助功能」中允许「随手新建」，用于自动进入文件名编辑框。授权后从菜单栏退出应用，再重新打开。
3. 在系统询问时允许「随手新建」控制「访达」，用于选中新文件。此权限可在「隐私与安全性 → 自动化」中管理。

## 使用

在桌面或 Finder 文件夹的空白处右键，选择「新建文件 → 文件类型」，输入名称后按回车确认。应用通过菜单栏提供使用说明和退出入口。

### 文件类型

| 菜单 | 创建内容 |
| --- | --- |
| TXT | 空白 UTF-8 文本 `.txt` |
| RTF | 空白富文本文档 `.rtf` |
| XML | 包含 UTF-8 声明与根节点的 `.xml` |
| Word / WPS 文字 | 空白文档 `.docx` |
| Excel / WPS 表格 | 含一个空白工作表的 `.xlsx` |
| PPT / WPS 演示 | 含一张空白幻灯片的 `.pptx` |
| Markdown | 空白 `.md` |

WPS 入口使用 `.docx`、`.xlsx` 和 `.pptx` 标准格式。文件的打开应用与图标由 macOS 文件关联决定，同一格式的 Office 和 WPS 入口可能显示相同图标。

### 自定义与模板

「自定义创建新文件…」用于输入带扩展名的完整名称。RTF、XML 和 Office 格式会写入对应的文档内容，其余扩展名创建空白文件。

「从模板创建…」用于选择一个普通文件，将其内容完整复制到目标目录，适合复用常用文档、配置和代码模板。需要特定内容结构的格式可以使用对应的有效文件作为模板。

## 开发

项目使用 Swift、AppKit 和 Finder Sync。Finder 扩展负责菜单及目标目录，主程序负责创建文件、选中目标并进入 Finder 原生文件名编辑框。文件写入采用排他创建，连续请求依次处理。

安装 Apple Command Line Tools 后，在源码目录执行：

```bash
bash Scripts/build.sh /absolute/path/to/empty-build-directory
bash Scripts/test.sh
```

`Resources/Templates` 包含构建所需的空白 Office 模板。默认构建采用本地 ad-hoc 签名；配置 `NEWFILE_SIGN_IDENTITY` 可选择 Apple 签名身份。面向其他 Mac 分发时，可按 Apple 流程完成 Developer ID 签名与公证。

当前已有 115 项自动化检查，覆盖文件内容、菜单映射、重名处理、路径传递和并发创建。详细验证记录见 [VALIDATION.md](VALIDATION.md)。

## 卸载

在系统设置中关闭「随手新建」Finder 扩展，从菜单栏退出应用，再删除应用。
