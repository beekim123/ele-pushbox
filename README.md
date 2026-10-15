# 箱途 · Cratebound

> 项目名在 2026-10-15 由「推箱子：沙与水」改为「箱途 / Cratebound」。名字只在 `content/i18n/*.json` 的 `game.title` 中定义；内部标识（如 `pushbox.art/1`）不随名字改变。

横版、侧视、按格移动的推箱解谜。沙、水、气体、火和冰由 [ele-base-cpp](https://github.com/beekim123/ele-base-cpp) v1.2.0 真实模拟。

**当前阶段（2026-10-15）**：设计与第 1 章美术已完成，57 项美术已由用户确认；第 2–5 章的材料、机关与特效已在工作台中画好，等待用户确认。Godot 游戏本体由开发方按 [交接提示词（正式版）](docs/handoff/gpt-refactor-prompt.md) 在 `game/` 中重新构建。进度见 [docs/status.md](docs/status.md)。

## 从这里开始

| 想做什么 | 入口 |
|---|---|
| 查看和确认美术 | 双击打开 `workbench/index.html`（不需要安装任何东西） |
| 了解玩法 | [游戏设计](docs/design/game-design.md) |
| 了解当前进度与下一步 | [项目进度](docs/status.md) |
| 文档导航 | [docs/README.md](docs/README.md) |

## 目录

| 目录 | 内容 |
|---|---|
| `docs/` | 设计、审核记录、SDK 事实、交接说明 |
| `content/levels/` | 关卡规格（设计数据），以及设计模型检查结果 |
| `art/` | 美术源数据、确认记录、导出文件 |
| `workbench/` | HTML 美术与场景预览工作台 |
| `tools/` | 关卡检查、美术构建 / 导出 / 确认脚本（Node 18+，无第三方依赖） |
| `third_party/` | SDK 运行库（macOS arm64）、字体及全部许可证 |

## 常用命令（仓库根目录，Node 18+）

```sh
node tools/check-levels.mjs --write          # 关卡设计模型检查（不是 SDK 验证）
node tools/art.mjs build                     # 校验美术源数据、导出 PNG 与清单、更新工作台数据
node tools/art.mjs verify                    # 导出与确认记录一致性检查
node --test tests/art-pipeline.test.mjs      # 美术流程测试（临时目录，不碰真实确认记录）
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
