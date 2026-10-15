# 渡界人 · PORTITOR

> 游戏名在 2026-10-15 定为《渡界人》/ PORTITOR（此前用过「推箱子：沙与水」「箱途 / Cratebound」）。名字只在 `content/i18n/*.json` 的 `game.title` 中定义；内部标识（如 `pushbox.art/1`）不随名字改变。

横版、侧视、按格移动的推箱解谜。沙、水、气体、火和冰由 [ele-base-cpp](https://github.com/beekim123/ele-base-cpp) v1.2.0 真实模拟。

**当前阶段（2026-10-15）**：游戏分为关卡模式、配送模式（核心）、地狱模式，见[总纲](docs/design/vision.md)；先重构游戏并做关卡模式。第一批关卡是第 1 组「基础」7 关 + 第 2 组「水与机关」9 关，规格已写好（`content/levels/lab/`）。主角是万界渡口的渡界人（`char.portitor`，已确认）。Godot 重构按 [交接提示词](docs/handoff/gpt-refactor-prompt.md) 进行，**目前暂停，等用户说开始**。进度见 [docs/status.md](docs/status.md)。

## 从这里开始

| 想做什么 | 入口 |
|---|---|
| 查看进度、机制、关卡和美术，确认美术 | 双击打开 `workbench/index.html`（不需要安装任何东西） |
| 了解游戏整体设计 | [总纲](docs/design/vision.md) |
| 了解玩法 | [游戏设计](docs/design/game-design.md) |
| 了解当前进度与下一步 | [项目进度](docs/status.md) |
| 文档导航 | [docs/README.md](docs/README.md) |

## 目录

| 目录 | 内容 |
|---|---|
| `docs/` | 设计、审核记录、SDK 事实、交接说明 |
| `content/catalog/` | 模式、机制组与关卡计划、机制目录、物品、货物、怪物、增益 |
| `content/levels/` | 关卡规格（按 `<模式>/<组>/` 存放），以及设计模型检查结果 |
| `art/` | 美术源数据、确认记录、导出文件 |
| `workbench/` | HTML 美术与场景预览工作台 |
| `tools/` | 关卡检查、美术构建 / 导出 / 确认脚本（Node 18+，无第三方依赖） |
| `third_party/` | SDK 运行库（macOS arm64）、字体及全部许可证 |

## 常用命令（仓库根目录，Node 18+）

```sh
node tools/check-levels.mjs --write          # 关卡设计模型检查（不是 SDK 验证）
node tools/art.mjs build                     # 校验美术源数据、导出 PNG 与清单，再构建内容目录，更新工作台数据
node tools/art.mjs verify                    # 导出、确认记录与内容目录的一致性检查
node tools/content.mjs check                 # 只检查目录与关卡规格（机制、关卡计划、美术引用）
node --test tests/art-pipeline.test.mjs tests/content.test.mjs   # 流程测试（临时目录，不碰真实数据）
node tests/workbench.e2e.cjs                 # 工作台浏览器测试（需要 Playwright + Chromium）
python3 tools/build-font.py                  # 新增界面文字后重建像素字形（需要 Pillow）
```

## 旧实验项目

此前的实验工程（v0.3 Demo、36 关实验关卡池、旧 Art Lab、旧文档与测试证据）完整保留在提交 `0fae58c`（分支 `codex/art-ui-polish`）以及 `main` 分支。查阅示例：

```sh
git show 0fae58c:pushbox/scripts/session.gd
git worktree add ../pushbox-legacy 0fae58c   # 检出完整旧项目
```

旧内容只作历史参考，不是新方案的要求。
