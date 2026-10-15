# 文档导航

每个主题只有一个有效文档。旧文档在快照 `0fae58c` 中，不作为执行依据。

| 文档 | 用途 |
|---|---|
| [status.md](status.md) | 当前阶段、已验证的内容、下一步与负责人 |
| [design/vision.md](design/vision.md) | **总纲**：渡界人 · PORTITOR 与万界渡口、三个模式、内容分层、路线图、已定事项 |
| [design/worlds.md](design/worlds.md) | 渡口与各个地区（世界）：取材于世界各地文化的原则、地府·酆都、地区专属机制 |
| [design/characters.md](design/characters.md) | 主角设计、收件人、渡口居民 |
| [design/game-design.md](design/game-design.md) | **玩法规则与关卡模式**：格子规则、材料、机关、系统、界面、关卡模式的组与关卡 |
| [design/mode-hell.md](design/mode-hell.md) | 地狱模式（设计稿） |
| [design/mode-delivery.md](design/mode-delivery.md) | **配送模式**（核心内容，设计稿，关卡模式完成后开工） |
| [design/progression.md](design/progression.md) | 局外养成（设计稿） |
| [design/naming.md](design/naming.md) | 名称：《渡界人》· PORTITOR（已定） |
| [design/architecture.md](design/architecture.md) | **工程结构与扩展机制**：分层、`game/` 目录、注册表、事件、存档、机制接口、怎么加新机制和新系统 |
| [design/ids.md](design/ids.md) | **资源编号与游戏映射**：全局编号、id-map、以工作台为准的规则 |
| [design/dialogue.md](design/dialogue.md) | 对话气泡与对话系统（气泡已在工作台，数据与触发器是后续） |
| [design/workbench.md](design/workbench.md) | 工作台：统一管理美术、机制与关卡，与游戏保持一致 |
| [design/art-direction.md](design/art-direction.md) | 美术规范 |
| [design/art-pipeline.md](design/art-pipeline.md) | 美术源数据、版本、确认、导出与 Godot 交付 |
| [design/asset-inventory.md](design/asset-inventory.md) | 需要的资产、尚缺的资产、旧 42 项的去向 |
| [audit/2026-10-15-design-audit.md](audit/2026-10-15-design-audit.md) | 本轮审核发现与决定 |
| [research/2026-10-15-mode-references.md](research/2026-10-15-mode-references.md) | 配送模式、地狱模式、局外养成与名称的调研来源 |
| [research/2026-10-15-competitors.md](research/2026-10-15-competitors.md) | 市面上有没有类似的游戏、我们的独特之处、要避开的坑 |
| [reference/sdk-v1.2-verified.md](reference/sdk-v1.2-verified.md) | 逐条核对源码的 SDK 事实 |
| [handoff/gpt-refactor-prompt.md](handoff/gpt-refactor-prompt.md) | 交给开发方（GPT）的完整重构提示词 |

关卡规格在 `content/levels/`，机制、模式、物品等目录在 `content/catalog/`，美术数据在 `art/`。

维护约定：每个主题只有一个文档，修改时只改对应文档并写更新记录；各种清单（机制、关卡计划、货物等）以 `content/catalog/` 为准，文档中的表格只作说明；进度只写在 `status.md`；不新建平行方案。
