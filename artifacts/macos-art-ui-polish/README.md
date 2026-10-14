> 当前包对应补修前 full-04 的有效通过版本。芦苇 / 云灵位移取整与飞蛾画布 / 透明度的补修尚未入包；补修版 T8 门禁未通过，不能把本包当作当前源码的最终交付。

# macOS 美术 / UI 翻新试玩候选 0.4.1

[下载 / 打开 DMG](Pushbox-art-ui-polish-macos-arm64.dmg) · 31.0 MiB · Apple silicon / macOS 15.6+。

将 Pushbox.app 拖到 Applications 后启动；无需另装 Godot / SDK。大厅 → 闯关模式；Q/E 切世界，Tab 观察池，F 全景 / 原生，原生模式方向键或拖动平移。Z 撤销，R 重开，Esc 返回。大厅 B 查看六主题展示图。

包内 2877 项回放 / 预演 / 教学 / 字体 / SDK 检查零失败；SDK 字节不变，codesign 深度严格验证及 DMG 完整性通过，实际只读挂载 GUI 启动通过。见 [manifest](manifest.json)、[GUI 验证](gui-validation.json) 与 `logs/`。

ad-hoc 测试签名，未 Apple 公证；如 macOS 拦截，可在隐私与安全性中选择「仍要打开」。候选未正式发布，旧 stage2a 安装包保留。

当前无需你操作。下一步由本任务 Codex 完成补修版全量性能门禁后重建包，再交用户验收。

SHA256：`74d92580b3e7e1d55fc1eea76bda173ef666093a39360626e682c9319f706c83`
