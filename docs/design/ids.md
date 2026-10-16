# 资源编号与游戏映射（有效）

2026-10-15 用户要求：HTML 工作台里每个资源都标上唯一编号；真实游戏里的资源要和 HTML 统一，做映射关系，**以 HTML 为准**。

## 1 全局编号

每个资源有一个全局唯一编号 `空间:编号`（uid）。同一个本地编号可以出现在不同空间（`recipient:ghost` 幽灵收件人、`monster:ghost` 幽灵怪物；`art:item.sandbag` 是沙袋图标，`item:sandbag` 是沙袋道具），uid 不会撞。

| 空间 | 是什么 | 来源（以此为准） | 游戏里的位置 |
|---|---|---|---|
| `art` | 美术资产（精灵、主题、材料、界面布局） | `art/source/<分类>/<编号>.json` | 精灵 `res://generated/art/<编号>.tres`；主题 `res://generated/themes/<编号>.tres`；材料 `res://generated/materials/<编号>.tres`；界面 `res://ui/screens/<名>.tscn` |
| `level` | 关卡规格 | `content/levels/<模式>/<组>/<编号>.json` | `res://generated/content/levels/<模式>/<组>/<编号>.json` |
| `room` | 配送模式的房间模板（[delivery-maps.md](delivery-maps.md)） | `content/rooms/<地区>/<编号>.json` | `res://generated/content/rooms/<地区>/<编号>.json` |
| `mode` `group` | 模式、机制组（章） | `content/catalog/modes.json`、`groups.json` | `res://generated/content/catalog/<目录>.json#<编号>` |
| `mechanic` | 机制 | `content/catalog/mechanisms.json` | 规则代码 `res://gameplay/mechanics/<编号>.gd` |
| `world` `recipient` `cargo` `combo` `monster` `item` `buff` `upgrade` `badge` `event` `slice` | 设计目录里的条目（`slice` 是可玩切片，即一局配送的配置） | `content/catalog/<目录>.json` | `res://generated/content/catalog/<目录>.json#<编号>` |
| `text` | 界面与台词文字的键 | `content/i18n/zh-Hans.json` 与 `content/i18n-<名>/zh-Hans.json`（英文在同目录 `en.json`；一个键只在一张表里） | `tr:<键>`（TranslationServer） |

以后新增的空间（`dialogue` 对话、`quest` 委托、`npc` 居民、`sfx` 音效、`music` 音乐、`shop` 商店货架……）照同样的方式加进 `tools/lib/ids.mjs` 的 `DOMAINS`，写清来源和游戏路径。

编号格式：美术 `分类.名字`（小写，如 `mech.lift`）；关卡 `字母 + 两位数字`（`W08`）；文字键 `点分小写`（`level.W08.title`）；其他 `小写字母、数字、下划线、连字符`。格式不对或重复都是内容检查的错误。

## 2 映射文件

`node tools/content.mjs build`（`node tools/art.mjs build` 也会调用它）生成 `content/export/id-map.json`（格式 `pushbox.idmap/1`）。每一项：

```json
{"uid": "level:W08", "domain": "level", "id": "W08", "name": "让桥塌下去",
 "source": "content/levels/lab/water/W08.json",
 "game": "res://generated/content/levels/lab/water/W08.json",
 "sha256": "…"}
```

美术项另有 `version`、`hash`（内容哈希）、`approved`。工作台「编号映射」页可以按空间浏览、搜索、复制编号，点编号跳到对应的资产、关卡、机制或目录页；资产页和关卡页也显示自己的 uid 和游戏路径。

## 3 规则（游戏方必须遵守）

1. **以工作台为准**：新资源先在本仓库加（美术进 `art/source`、内容进 `content/`），跑构建生成 id-map，游戏再导入。游戏不能自己发明编号，也不能改名。
2. **游戏只用 uid 找资源**：代码、场景、存档里写 uid（例如 `"art:mech.lift"`、`"item:sandbag"`），通过注册表 `Registry.get(uid)` 取资源，不写死文件路径。导入脚本根据 id-map 生成 `res://generated/` 下的文件和 `res://generated/ids.gd`（每个 uid 一个常量，拼错在编辑器里就能发现）。
3. **`res://generated/` 只由导入脚本写**，不手改；每次导入前清空重建。
4. **编号一旦发布就不改、不复用**。要换掉一个资源：加新编号，旧条目标 `deprecated` 并写 `replaced_by`；存档迁移按这个映射走。
5. **数据里的引用**：同一种类型的字段直接写本地编号（收件人的 `likes` 写货物编号，因为字段已经说明是货物）；跨类型、不确定类型的引用（对话的 `speaker`、委托的奖励、商店货架）一律写 uid。
6. **测试**：游戏的 headless 测试要检查 (a) id-map 里每个 uid 在游戏路径上都存在，美术与关卡的哈希一致；(b) 游戏代码和场景里出现的每个 uid 都在 id-map 里；(c) `res://generated/` 里没有 id-map 之外的文件。结果写进验证报告。
