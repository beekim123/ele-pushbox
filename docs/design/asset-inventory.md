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

## 3 主角与 2026-10-15 的新版本

| 资产 | 用途 | 状态 |
|---|---|---|
| `char.portitor` | 主角"斗笠灯笈"渡界人（[角色设计](characters.md) 1.2），21 帧，动作名称与 `char.miner` 相同 | **已确认**（`APR-0003`） |
| `char.portitor_alt` | 备选概念 B 铜铃机偶、C 狐面行者（各一帧），只用于比较 | 草稿，不进游戏 |
| 6 个主题（v2）、`material.chapter2_5`（v2）、8 个界面布局（v3） | 换标题"渡界人"、换主角、字体加字之后生成的新版本；主题和材料的像素只有主角处不同，界面多了标题和第 2–5 章的新简介 | 待用户重新确认 |

`char.miner` 不再是主角，保留为收件人"老矿工"和训练场教官的素材。

## 3b 关卡模式 v2 第 2 组的新机关（候选，待确认）

| 资产 | 用途 | 关卡 | 状态 |
|---|---|---|---|
| `mech.portal` | 传送阵：刻着发光符文的石盘；`idle` 4 帧（光点上升）、`glow` 2 帧（刚传过来时） | W09 | 候选 |
| `mech.bridge` | 承重桥板：沙岩石板，`intact` 与 `strained`（载重等于承重时出现裂纹）；板面刻痕由 `matter.js` 绘制 | W08 | 候选 |

第 2 组其他机关（开关、升降台、按钮、收集斗与刻度）沿用 `APR-0002` 已确认的美术。

## 3c 配送模式第一个可玩切片（第 4 步候选，待确认）

2026-10-16 画好，共 26 项，全部 `stage: review`，**用户确认前不得进游戏**（[配送切片](delivery-slice.md) 第 13 节）。工作台「确认」页逐项看；「地图预览」可以在房间里、在实时播放里一起看（左栏「美术候选」开关，关掉后改回字母方块占位）。

| 资产 | 用途 | 动画 |
|---|---|---|
| `monster.rat_swarm` | 怪物·鼠群：三只棕色红眼老鼠堆成一窝（和灰色单只的生态小老鼠区分开） | walk、chase（前倾追人）、flee（背着偷到的沙袋）、stunned（头上冒星）、trapped（被困，抬头冒汗） |
| `monster.skeleton_guard` | 怪物·骷髅守卫：旧铁盔红缨、红眼、手持长矛 | walk、trapped（挥手、张嘴）、attack（长矛前刺）、ko（散成一堆） |
| `fx.monster_poof` | 怪物被压倒 / 埋住 / 摔晕时的一团烟和星星 | 一次 4 帧 |
| `char.zombie` | 收件人·僵尸：绿皮、破蓝衣、两手前伸 | idle、walk（闲逛）、win（举手收货） |
| `char.goblin_smith`、`obj.goblin_forge` | 收件人·地精铁匠（大耳朵、皮帽、皮围裙、铁锤）和他家的铁砧与炭盆（表示"很热"） | work（打铁）、win；炭火 idle |
| `char.miner` | 收件人·老矿工：**沿用已确认的旧主角**，收货用 win | — |
| `char.turtle_keeper` | 驿站的龟掌柜：背着整间铺子（红白遮阳篷、货架）的老乌龟，戴眼镜、白眉白须，32 × 32 | idle（眨眼）、talk |
| `char.lucky_cat` | 滚轮台上的招财猫：举起的爪子就是拉杆，挂金铃、抱金币，32 × 32 | idle（招手）、pull（拉下拉杆）、win |
| `mech.ferry_gate` | 渡门：红色牌坊 + 小灯笼，门里一团慢慢上升的暗蓝雾，32 × 32 | idle |
| `avatar.old_miner`、`avatar.zombie`、`avatar.goblin_smith` | 收件人头像（24 × 24），滚轮与结算用 | — |
| `cargo.letter`、`cargo.vase`、`cargo.ice_cream` | 货物图标：信件（红火漆）、青花瓶（有"裂了"一帧）、冰淇淋（有"在化"一帧） | — |
| `item.coin` | 金币：金色方孔钱，房间里转动、界面里当图标 | default、spin |
| `item.first_aid`、`item.rope_ladder`、`mech.rope_ladder` | 急救包、绳梯图标；放下后的绳梯（和木梯一样能爬，一眼看出是道具放的） | — |
| `ui.delivery_icons` | 配送 HUD 图标：心 / 空心、用时、易碎、会化、很热、完好度格（满 / 空）、背包空格、方向箭头、放倒数 | — |
| `ui.screen.reels` | 滚轮台：招财猫、货物轮与收件人轮、两边的规矩、"喜欢"加成、重转券 | 界面 |
| `ui.screen.shop` | 驿站货架：龟掌柜的对话气泡（回一颗心）、三样货的价格与库存（卖完变暗）、背包与沙袋 | 界面 |
| `ui.screen.settlement`、`ui.screen.settlement_fail` | 送达结算（完好度、用时、喜欢三个系数、小费、拾到、合计、评级）与失败结算（带回一半金币） | 界面 |
| `ui.screen.delivery_hud` | 局内 HUD：心、货物与完好度、规矩图标、金币、沙袋、3 个背包格、用时、小地图 | 界面 |
| `ui.screen.delivery_pause` | 暂停菜单（配送）：**沿用已确认的暂停菜单画法**，只换菜单项（继续、重来这个房间、放弃这一单、设置、回大厅） | 界面 |

界面的文字在 `content/i18n-delivery/`，补的 46 个字形在 `workbench/js/core/font-delivery.js`，画法在 `workbench/js/core/ui-delivery.js`；已确认的 82 项一个字节都没变（[美术流程](art-pipeline.md) 第 2 节）。

## 4 尚未制作

| 资产 | 章 | 说明 |
|---|---|---|
| 放置炸药的人物动作（可复用"倒"的姿势） | 3 | 视试玩反馈决定 |
| 配送模式的主角动作：拿小件、抬大件、受伤、倒下、冰上滑、游泳、坐着 | 配送模式 | 主角确认后制作 |
| 配送模式的地区、收件人、怪物、货物、道具美术 | 配送模式 | 第一个切片的候选见 3c；其余按内容层逐个制作（[地区](worlds.md) 第 5 节） |
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
