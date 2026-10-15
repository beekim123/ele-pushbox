# 文档导航

每个主题只有一个有效文档。旧文档在快照 `0fae58c` 中，不作为执行依据。

| 文档 | 用途 |
|---|---|
| [status.md](status.md) | 当前阶段、已验证的内容、下一步与负责人 |
| [design/game-design.md](design/game-design.md) | **唯一有效的玩法设计**：规则、章节、关卡、系统、界面 |
| [design/art-direction.md](design/art-direction.md) | 美术规范 |
| [design/art-pipeline.md](design/art-pipeline.md) | 美术源数据、版本、确认、导出与 Godot 交付 |
| [audit/2026-10-15-design-audit.md](audit/2026-10-15-design-audit.md) | 本轮审核发现与决定 |
| [reference/sdk-v1.2-verified.md](reference/sdk-v1.2-verified.md) | 逐条核对源码的 SDK 事实 |
| [handoff/gpt-refactor-prompt.md](handoff/gpt-refactor-prompt.md) | 交给开发方（GPT）的完整重构提示词 |

关卡规格在 `content/levels/`，美术数据在 `art/`。

维护约定：修改玩法只改 `game-design.md` 并写更新记录；进度只写在 `status.md`；不新建平行方案。
