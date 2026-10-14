# 仓库整理验证记录

日期：2026-10-14（Asia/Shanghai）。验证对象为从 Git 暂存文件导出的独立副本，包含随仓的 macOS arm64 SDK 动态库、全部素材与源码。运行环境为 Godot 4.7.2、macOS/OpenGL、Apple M3；所有脚本顺序执行，计算 worker 为 1。

## 验证结果

| 检查 | 结果 | 证据 |
|---|---|---|
| 常规脚本 | 13/13 通过 | functional-summary.json 与 logs/ |
| SDK 和核心规则保留 | 13/13 通过 | core-preservation.json |
| T8 结算帧峰值 | 未通过；D3 5.372 ms，大于 4 ms 阈值 | performance-macOS.json 与 logs/performance.log |
| T8 预演显示延迟 | 最大 85.581 ms，小于 100 ms 阈值 | performance-macOS.json |
| 脚本语法与交付完整性 | Bash、Python 和构建脚本内 Python 语法检查通过；运行库 SHA、68 个精灵文件及启动权限已核对 | 本轮静态检查 |

14 个测试脚本均执行完毕，13 个通过，1 个性能脚本失败。完整摘要与被验证的运行文件哈希见 [verification.json](verification.json)。

常规脚本以 nice 10 执行；性能测量以普通调度优先级单独执行。历史通过数据保留在 `artifacts/v03/`，本次结果不覆盖历史数据，也不把本次性能失败改记为通过。

## 验证范围与后续处理

本轮验证用于确认仓库中的候选代码和资源可加载、可运行，并记录当前技术状态。SDK 没有重新编译；4/8 worker、T10 新玩家试玩、用户反馈的屏幕适配和人物越障 Bug 排查均未执行。

用户已要求 Bug 留到后续处理，本次按授权推送候选快照。性能失败保留为待处理项，后续由 Codex 在用户恢复问题排查时定位并验证；成品用户验收与正式发布尚未完成。
