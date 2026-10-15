# 工作台：统一管理美术、机制与关卡

状态：有效（2026-10-15 改造）。工作台是 `workbench/index.html`，双击即可打开，不需要服务器。总纲见 [vision.md](vision.md)。

## 1 目标

以后会有更多美术、机制、关卡和配送模式的设计数据。工作台要做到两件事：

1. **一处看全**：每个机制从设计到可玩走到了哪一步，用到哪些美术、确认了没有，对应哪些关卡，游戏里验证过没有。
2. **和游戏一致**：工作台和 Godot 游戏读同一份数据、按同一套绘制规则出图；游戏的自动验证结果再回到工作台显示。两边不各写一份。

## 2 唯一数据来源

| 数据 | 位置 | 谁写 | 谁读 |
|---|---|---|---|
| 美术源数据与确认记录 | `art/source/**`、`art/approvals.json` | 美术负责人；确认只由 `node tools/art.mjs approve` 写入 | 工作台；`art.mjs` 导出 `art/export/manifest.json` 给 Godot |
| 绘制与规则代码 | `workbench/js/core/*.js` | 美术 / 设计负责人 | 工作台、`art.mjs`；Godot 照着移植 |
| 模式、机制组与关卡计划 | `content/catalog/modes.json`、`groups.json` | 设计负责人 | 工作台；`content.mjs` 导出给 Godot |
| 机制目录 | `content/catalog/mechanisms.json` | 设计负责人 | 同上 |
| 物品、货物、怪物、增益 | `content/catalog/items.json`、`cargo.json`、`monsters.json`、`buffs.json` | 设计负责人 | 同上 |
| 关卡规格 | `content/levels/<模式>/<组>/<编号>.json` | 设计负责人或开发方 | 工作台、`check-levels.mjs`、Godot |
| 界面文字 | `content/i18n/`、`content/i18n-extra/` | 设计负责人；开发方只加 `i18n-extra` | 工作台、Godot |
| 游戏验证报告 | `game/reports/verification.json` | Godot headless 测试自动生成 | `content.mjs` 读入，工作台显示 |

规则：任何列表（有哪些机制、哪些关、哪些货物）只在目录文件里维护一份；设计文档里的表格是说明，编号与状态以目录文件为准。

## 3 状态由数据算出，不手写

| 对象 | 状态 | 怎么判断 |
|---|---|---|
| 关卡 | 概念 → 有规格 → 设计模型通过 → SDK 验证通过 | 计划在 `groups.json`；规格文件存在且有地图；`check-levels` 结果；验证报告 |
| 机制 | 提议 → 已设计 → 有规格 → 已验证 → 可玩 | 没有计划关卡 = 提议；有计划关卡 = 已设计；全部关卡有规格 = 有规格；全部关卡验证通过 = 已验证；再加上用到的美术全部已确认 = 可玩 |
| 美术 | 草稿 / 待确认 / 已确认 | 确认记录中版本与哈希都一致才算已确认（[美术流程](art-pipeline.md)） |

## 4 Godot 验证报告（`game/reports/verification.json`）

开发方的 headless 测试每次运行后写这个文件，并提交到仓库。格式：

```json
{
  "format": "pushbox.verification/1",
  "generated": "2026-11-01T10:00:00Z",
  "commit": "游戏代码的 git 提交",
  "sdk": "v1.2.0 dacb93e",
  "levels": [
    {"id": "M01", "won": true, "replays": 3, "consistent": true, "undo_ok": true,
     "max_ticks": 412, "tick_limit": 4000,
     "checks": [{"text": "验收条目原文", "ok": true}],
     "screenshot": "game/reports/shots/M01.png"}
  ],
  "samples": [{"id": "sdk.sand_overflow", "ok": true, "detail": "邻格溢出 37 cell"}],
  "references": [{"name": "level.M01", "diff_pixels": 0}]
}
```

一关算"验证通过"：`won`、`consistent`、`undo_ok` 都为真，`replays` ≥ 3，`max_ticks` < `tick_limit`，并且每个 `checks` 都通过。报告缺失或过期时，工作台如实显示"尚无验证"，不推测。

## 5 工具

| 命令 | 作用 |
|---|---|
| `node tools/art.mjs build` | 美术构建（版本、导出图、参考图），最后自动运行内容构建 |
| `node tools/content.mjs check` | 检查目录和关卡规格：编号重复、引用不存在的机制 / 资产 / 主题、关卡规格与计划不一致、规格放错目录等。有错误时退出码非 0 |
| `node tools/content.mjs build` | 检查后写出 `content/export/content-manifest.json`（给 Godot：模式、组、按顺序的关卡和规格文件的哈希、机制）和 `workbench/data/content.js`（给工作台） |
| `node tools/art.mjs verify` | 美术校验，同时要求内容检查没有错误 |
| `node tools/check-rooms.mjs --write` | 配送房间模板的静态检查与可通性检查，按切片生成 300 个种子的地图逐间核对，再用实时规则回放每个模板的演示（含翻转）；写出 `content/rooms-check.generated.json` 与 `content/export/delivery-golden.json`（地图对照表 + 回放记录）。模板改了没重跑、演示没达到预期，内容检查都会报错 |

## 6 页面

| 页面 | 内容 |
|---|---|
| 总览 | 三个模式的状态；关卡模式各组的进度；美术确认数量；内容检查的错误与警告；最近一次游戏验证报告 |
| 模式与关卡 | 模式 → 组 → 关卡；每关显示规格、设计模型、SDK 验证、美术四项状态，有地图的关可以直接打开预览 |
| 机制 | 机制目录：归属（SDK / 游戏层）、需要的 SDK 能力、状态、对应关卡、用到的美术及确认情况 |
| 地图预览 | 配送模式：按种子生成整张地图（和游戏同一套代码）、每一间的模板与检查过的路线、全部房间模板的检查结果（[delivery-maps.md](delivery-maps.md)）；用实时规则播放每个模板的演示、用键盘试玩一间或整张图，右栏显示时间、心、金币、货物和结算（[delivery-realtime.md](delivery-realtime.md) 第 15 节） |
| 设计数据 | 可玩切片、地区、收件人、货物、怪物、道具、增益等目录（配送模式的设计数据） |
| 场景 | 代表场景、关卡、界面画面的预览（原有） |
| 资产与动画、编辑与对比、确认、导出 | 原有的美术流程 |

## 7 一致性检查清单

| 检查 | 方法 | 自动 |
|---|---|---|
| 目录与关卡规格互相引用正确 | `content.mjs check` | 是 |
| 工作台画面 = 导出 PNG | `tests/workbench.e2e.cjs` | 是 |
| 导出 PNG = 源数据，确认记录完整 | `art.mjs verify` | 是 |
| 游戏画面 = 参考图 | Godot 截图与 `art/export/reference/` 逐像素比较，结果写进验证报告的 `references` | 待开发方实现 |
| 游戏关卡 = 规格 | Godot 只从 `content-manifest.json` 读关卡清单和规格，并校验文件哈希 | 待开发方实现 |
