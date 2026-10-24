# 安装与故障处理

当前提供源码构建安装。需要 macOS 13+、Swift 5.9+ 和 macOS SDK，构建与运行已在 Apple Silicon 上验证。没有经过 Apple 公证的下载版，Intel 构建与运行尚未验证。

想交给 AI agent？使用[一句话安装指引](agent-install.md)。想自己安装？按下面三步操作。

## 从源码安装

1. 从 [GitHub 仓库](https://github.com/viowai/7viow-talis) 的 **Code → Download ZIP** 下载并解压，或克隆该仓库。在含 `Package.swift` 的目录打开终端。
2. 先检查环境：

```bash
bash scripts/install_app.sh --check
```

缺少开发工具时，运行 `xcode-select --install`，在 macOS 弹窗中完成安装，再重试。已安装完整 Xcode 时，通常无需另外安装 Command Line Tools。遇到许可提示，由你在系统界面完成。详见 [Apple 开发工具安装说明](https://developer.apple.com/documentation/xcode/installing-the-command-line-tools)。

3. 保留编辑中的文字并退出旧 Talis，然后执行：

```bash
bash scripts/install_app.sh && open /Applications/Talis.app
```

完成后，按 [第一次使用](../README.md#完成第一次使用) 先编辑并复制一段文字。安装过程不需要 API Key，也不需要付费 Apple Developer 会员。

## 日常使用

Talis 的标准安装位置是 `/Applications/Talis.app`。从 Finder 的“应用程序”、Spotlight 或 Dock 打开，使用 `Option + Space` 唤起。

| 内容 | 位置 |
|---|---|
| 日常 App | `/Applications/Talis.app` |
| 个人模板、应用配置 | `~/Library/Application Support/Talis` |
| API Key | macOS Keychain，按供应商分开 |
| 源码构建缓存与本地打包输出 | `~/Library/Caches/Talis/Build` |

安装器先把构建产物完整复制到应用目录内的暂存位置并校验，再备份旧 App、安装新 App。替换或最终校验失败时会恢复原 App。如果系统阻止恢复，错误信息会给出保留的备份位置。升级成功后，原 App 留在 `~/Library/Application Support/Talis/Backups`，个人模板和设置保持原位。

## 权限不足时用 Finder 安装

如果当前账户不能写入 `/Applications`，先构建：

```bash
bash scripts/build_desktop_app.sh
open "$HOME/Library/Caches/Talis/Build/desktop"
```

退出现用 Talis。已有 App 时先在个人备份目录保留一份，再用 Finder 把新 `Talis.app` 拖到“应用程序”，完成 macOS 管理员确认。不要把密码发送给 AI agent。

## 只构建

只构建、不安装：

```bash
bash scripts/build_desktop_app.sh
```

构建产物在 `~/Library/Caches/Talis/Build/desktop/Talis.app`。开发工具可以免费获取。首次编译需要等待，耗时取决于机器。项目没有外部 Swift Package 依赖。

## 常见问题

| 看到的情况 | 下一步 |
|---|---|
| 找不到 `scripts/install_app.sh` | 切到解压后的源码根。这里应有 `Package.swift` |
| 提示需要 Mac | 当前命令在 Windows、Linux 或云端运行。改用目标 Mac 的终端或本机 agent |
| 缺少 Swift / macOS SDK | 完成 Apple 开发工具安装后，运行 `bash scripts/check_environment.sh` 再检查 |
| 已装开发工具但仍报错 | 查看 `xcode-select -p`、`swift --version` 和 `xcrun --sdk macosx --show-sdk-path`。修正工具选择，不反复安装 Talis |
| 提示先退出 Talis | 保存或复制正在编辑的内容，正常退出后重试。安装器不会强制结束进程 |
| 无权写入“应用程序” | 使用上面的 Finder 安装路径并完成系统确认 |
| 下载 App 被 macOS 拦截 | 当前本地打包脚本未提供 Developer ID 签名和公证，使用源码构建。不要关闭系统保护 |
| App 打开但 AI 操作失败 | 从菜单检查当前供应商和 API Key。安装成功与模型账号可用是两个条件 |
| `Option + Space` 没有唤起 | 先打开 Talis，再检查其他工具是否占用同一快捷键 |

需要帮助时，在 [GitHub Issues](https://github.com/viowai/7viow-talis/issues) 附上 App 版本、macOS 版本、芯片类型、失败命令和错误信息。不要附 API Key、私人模板或完整个人配置。

## 本地 ZIP 与磁盘映像

```bash
bash scripts/package_local.sh
```

输出在 `~/Library/Caches/Talis/Build/packages`。磁盘映像包含 Talis.app 和“应用程序”快捷方式。脚本生成的是本地临时签名包，未取得 Developer ID 签名和 Apple 公证。其他 Mac 的默认 Gatekeeper 可能阻止打开。这些包不具备经过 Apple 公证的下载版体验。

## 更新和恢复

更新前退出 App。安装器仅替换应用包，用户数据独立保留。API Key 迁移完成后由 Keychain 管理，恢复旧版前先保留当前数据。过旧版本可能不认识新的供应商密钥存储，需要重新配置。

卸载时删除 `/Applications/Talis.app` 即可移除程序。若希望同时移除某供应商密钥，先在设置中选择该供应商并点击“移除 API Key”。个人模板需要保留时，不删除应用数据目录。
