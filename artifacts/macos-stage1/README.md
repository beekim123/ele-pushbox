# macOS 第一阶段安装包

更新：2026-10-14（Asia/Shanghai）。用户最终要求只制作 mac 安装包；Windows 请求已取消，第二阶段未启动。

安装包：[Pushbox-stage1-macos-arm64.dmg](Pushbox-stage1-macos-arm64.dmg)，**32,401,328 字节，约 31 MiB**。自包含 `.app`，已内置 Godot 4.7.2 和原 SDK，无需在目标电脑另装 Godot、Python 或 SDK。

适用 **Apple silicon（M1/M2/M3/M4 等）、macOS 15.6 或更新**；不支持 Intel Mac。应用包版本标识为 `0.3.1`，当前仍为第一阶段安装候选，尚未作正式发布。

## 安装与启动

1. 双击 DMG。
2. 将 `Pushbox.app` 拖到旁边的 `Applications`（应用程序）入口。
3. 从应用程序双击启动，在大厅进入教学模式，试玩 T01–T04。

本包使用 **ad-hoc 测试签名，未经过 Apple 公证**。其他电脑从网络取得后，系统可能要求在「系统设置 → 隐私与安全性」中选择「仍要打开」。未修改系统安全策略，也未使用个人开发证书。本机 `spctl` 返回 accepted，但原有环境显示 `override=security disabled`，因此这次 GUI 启动不能作为标准 Gatekeeper 环境免提示放行的证据。公开分发所需 Developer ID/公证不在本次已完成范围。[Godot 官方签名及公证说明](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_macos.html)。

## 验证与证据

- 包内发布运行环境：**201 项、0 失败**。T01–T04 全部作者动作/哈希、撤销/重做、大厅初始化、原始中文字体和 SDK 加载通过。测试在 `/private/tmp` 启动，无仓库路径或外装 Godot 依赖。[包内测试日志](logs/package-smoke.log)。
- `codesign --verify --deep --strict` 通过；DMG 的 `hdiutil verify` 通过。
- 只读挂载 DMG 后，实际从安装介质用 Launch Services 启动了 GUI；观察到完整大厅、中文像素字、模式卡片和进度显示正常。运行日志无错误。[GUI 日志](logs/gui-launch.log)。
- SDK 二进制与仓库原件 SHA-256 完全一致：`b084eb5ffad07cc4b790285156de1bf3ef1c33fd69a8bb7fd2d7c599f6c088c4`。没有重编 SDK，冻结的物理文件/D1–D5 未修改。
- 仅在临时导出副本中启用 ARM 导出要求的纹理格式，采用安全的应用标题，保留原始字体字节的非资源别名，并加入内部验证入口；正常启动直接进入大厅。导出的安全应用标题使用独立 user:// 目录，原仓库试玩存档未覆盖。官方模板先导出通用程序，再裁剪为 ARM64。
- Godot/SDK/Box2D/godot-cpp 及字体许可证随 `.app` 保存在 `Contents/Resources/Licenses/`。

完整包内文件指纹及 DMG 指纹见 [manifest.json](manifest.json)；官方模板来源与选择性下载 CRC/SHA 记录见 [template-source.json](template-source.json)。没有宣称已核验未下载的整套模板归档 SHA。

DMG SHA-256：

```text
f675a123470dc1403a81b881fb246ae7c4f5a2455fe6a65d65fb1dfe844d396b
```

可重复打包工具为仓库 `tools/package_macos.py`；需要现有 Godot 4.7.2 编辑器和匹配的 macOS 模板。安装包二进制已由 `.gitignore` 排除，源码和验证证据保留。

## 交接

当前阶段：**macOS 安装候选制作及技术检查完成，等待用户安装体验**。下一步由用户点击安装包，按上面的三步安装；如遇问题，在本聊天回复「mac 安装包问题：……」。当前无需用户补跑编译、测试或清理命令。本会话不启动 Windows 移植或第二阶段。
