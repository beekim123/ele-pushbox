# 资产清单（按 GD-2 设计）

每件资产的当前版本与确认状态以工作台「确认」页和 `art/export/manifest.json` 为准；本表只说明**需要什么**、**为什么**，以及旧资产的去向。

## 1 已确认（v1，`APR-0001`）

| 资产 | 用途 | 章 |
|---|---|---|
| `char.miner` | 主角 21 帧：待机、走、推、爬、挖、倒、落、胜利 | 全部 |
| `obj.crate_wood` / `obj.crate_iron` | 木箱 / 铁箱 | 1 / 2 |
| `mech.door`、`mech.plate`、`mech.link_symbol` | 门（开关动画）、压板、配对符号（圆、三角、方） | 1 |
| `mech.socket`、`mech.socket_lit`、`mech.exit_flag`、`mech.ladder` | 箱子槽、点亮叠加、出口旗、梯子 | 1 |
| `item.sandbag`、`item.bomb` | 背包图标 | 1 / 3 |
| `fx.land_dust`、`fx.dig_bits`、`fx.goal_spark` | 落地、挖土、点亮 | 1 |
| `theme.*`（6 个） | 地形图案、背景、生态清单：石牢、神庙、晶窟、古森、圣域、星站 | 1–5 + 扩展 |
| `fauna.*`（9 个）、`deco.*`（10 个） | 各主题的小动物与植物：蝙蝠、老鼠、苔藓、火把；金甲虫、垂藤、金莲；飞蛾、荧光蘑菇、紫晶；知更鸟、蝴蝶、野花、草丛；白鸽、云灵、雏菊；无人机、异星球芽 | 对应主题 |
| `ui.icons`、`ui.goal_lamp`、`ui.keycap`、`ui.panel`、`ui.cursor`、`ui.target`、`ui.class_icon` | 界面元素、目标高亮、观察模式图标 | 全部 |
| `ui.screen.lobby` / `chapters` / `levels` / `pause` / `hint` / `complete` / `settings` / `rulecard` | 界面布局参考 | 全部 |

第一个可玩闭环（第 1 章 + 菜单）需要的资产，以上已经全部覆盖。

8 个界面布局为接入第 2–5 章生成了 v2（`scene.js` 与语言表有改动），画面与 v1 逐像素相同，已由用户确认（`APR-0002`）。

## 2 第 2–5 组（v1，已确认，`APR-0002`）

在工作台「场景」页的「第 2–5 章代表场景」中整体查看，在「资产」页逐项查看。

| 资产 | 用途 | 章 |
|---|---|---|
| `material.chapter2_5` | 新材料的着色规则（程序化，`matter.js`）：碎石、引信、酸液、软岩 A / A′（同一刻纹）、硬岩、轻烟、沉雾、菌塞、木栅、冰 | 3–5 |
| `mech.lift`、`mech.button` | 升降台（台面 + 导轨）、按钮 | 2 |
| `mech.bin`、`mech.bin_gauge` | 收集斗内衬、0–4 格刻度与"满"（锁存） | 2、4 |
| `fx.splash`、`fx.ripple` | 入水水花、水上木箱的波纹（箱子下沉 3 px） | 2 |
| `fx.explosion`、`fx.rubble` | 爆炸（32×32）、裂岩崩落 | 3 |
| `fx.fire` | 燃烧（叠加在正在燃烧的格上） | 3、5 |
| `mech.lever` | 开关（释放口、火盆、喷口） | 4、5 |
| `mech.vine`、`fx.fizz` | 吸水藤梯（根 / 茎 / 顶）、酸蚀气泡 | 4 |
| `mech.torch`、`mech.frost_vent`、`mech.heat_vent`、`fx.frost` | 火盆、冷凝喷口、热喷口、结冰闪烁 | 5 |
| `ui.rule_icon` | 观察模式的规则图标：上浮、下沉、可燃、可酸蚀、冰、慢速粉末 | 3–5 |

## 3 主角重新设计（候选，待确认）

| 资产 | 用途 | 状态 |
|---|---|---|
| `char.portitor` | 新主角"斗笠灯笈"摆渡人（[角色设计](characters.md) 1.2），21 帧，动作名称与 `char.miner` 相同 | 待确认 |
| `char.portitor_alt` | 备选概念 B 铜铃机偶、C 狐面行者（各一帧），只用于比较 | 草稿，不进游戏 |

确认后，场景、大厅和界面里的主角都换成 `char.portitor`（8 个界面布局会生成新版本，和中文名一起再确认一次）；`char.miner` 改做收件人"老矿工"。

## 4 尚未制作

| 资产 | 章 | 说明 |
|---|---|---|
| 放置炸药的人物动作（可复用"倒"的姿势） | 3 | 视试玩反馈决定 |
| 配送模式的主角动作：拿小件、抬大件、受伤、倒下、冰上滑、游泳、坐着 | 配送模式 | 主角确认后制作 |
| 配送模式的地区、收件人、怪物、货物、道具美术 | 配送模式 | 按内容层逐个制作（[地区](worlds.md) 第 5 节） |
| 音效与音乐 | — | 不在本轮美术范围内 |

## 5 旧 42 项的处理（快照 `0fae58c` 中的 `tools/art-lab/js/data/assets.js`）

| 旧资产 | 决定 | 理由 |
|---|---|---|
| `miner_idle`、`miner_walk`、`miner_dig`、`miner_pour`、`miner_climb` | **重画并合并**为 `char.miner` | 补齐推、落、胜利动作；统一一张图集和动画表；加入背后的沙袋，作为角色辨识点 |
| `crate_wood_dungeon` / `_forest` / `_ruins` | **合并**为 `obj.crate_wood` | 同一种规则的物体在各章保持同一外观，玩家不用重新辨认 |
| `crate_iron_all` | **重画**为 `obj.crate_iron` | 冷灰色带铆钉，与木箱形成材质对比 |
| `icon_bomb`、`icon_sandbag`（0–7 满度） | **重画**为 `item.bomb`、`item.sandbag`（满 / 空） | 背包按"袋"计数，1 袋 = 1 格，不再显示满度 |
| `vine_ladder` | **保留概念**，第 4 章重画为 `mech.vine` | 游戏层机关仍在设计中 |
| `ruins_brazier` | **改为**第 5 章 `mech.torch` | 火盆变成可操作的点火开关 |
| `ui_keycaps` | **重画**为 `ui.keycap` | 方向键与字母键；Shift、Ctrl、Esc 等宽键由九宫格加文字绘制 |
| `ui_lobby_screen`、`ui_campaign_screen` | **重做**为 `ui.screen.*` | 新的章节、关卡结构 |
| `tile_forest_grass`、`tile_sky_marble`、`tile_cosmos_hull`、`tile_cave_sulfur` | **改为**程序化 `theme.*` 的地形图案（草皮、白石镶金、舱板警示条、粗糙岩洞） | 地形由着色器逐像素绘制，不用贴图 |
| `forest_bird`、`forest_butterfly`、`sky_dove`、`cloud_sprite`、`ruins_scarab`、`cave_moth`、`cosmos_drone`、`dungeon_bat` | **恢复并重画**（2026-10-15 用户决定） | 按美术规范第 6 节的生态规则重画为 `fauna.*`；`forest_frog` 暂不做，以免与水面玩法混淆 |
| `hazard_gargoyle`、`hazard_mole` | **删除** | 挑战模式移出规划 |
| `flower_sway`、`mushroom_glow` | **恢复并重画**为 `deco.forest_flower`、`deco.cave_mushroom` | 同上 |
| `wind_pinwheel`、`cloud_pad`、`cosmos_teleporter` | **删除** | 它们是机关而不是装饰，对应机制已移出主线 |
| `map_*`（6 张旧地图） | **删除**地图布局，主题风格由 `theme.*` 继承 | 旧关卡布局不再使用 |
